import 'dart:collection' show UnmodifiableListView;

import 'package:meta/meta.dart';
import 'package:yaml/yaml.dart';

import './list_mutations.dart';
import './map_mutations.dart';
import './source_edit.dart';
import './style.dart';
import './utils.dart';

/// An interface for modififying [YAML][1] documents while preserving comments and
/// whitespaces.
///
/// Users may define the default settings to be applied to these YAML modifications.
/// Note however that these settings only apply to portions of the YAML that are modified
/// by this class.
///
/// Most modification methods require the user to pass in an [Iterable<Object>] path that
/// holds the keys/indices to navigate to the element. Key equality is performed via
/// `package:yaml`'s [YamlMap]'s key equality.
///
/// For example,
///
/// ```yaml
/// a: 1
/// b: 2
/// c:
///   - 3
///   - 4
///   - {e: 5, f: [6, 7]}
/// ```
///
/// To get to `7`, our path will be `['c', 2, 'f', 1]`. The path for the base object is the
/// empty array `[]`. All modification methods will return a [ArgumentError] if the path
/// provided is invalid. Note also that that the order of elements in [path] is important,
/// and it should be arranged in order of calling, with the first element being the first
/// key or index to be called.
///
/// To dump the YAML after all the modifications have been completed, simply call [toString()].
///
/// [1]: https://yaml.org/
@sealed
abstract class YamlEditor {
  /// Returns a list of [SourceEdit]s describing the modifications performed on the
  /// YAML string thus far.
  UnmodifiableListView<SourceEdit> get edits;

  /// Style configuration settings for [YamlEditor] when modifying the YAML string.
  YamlStyle get defaultStyle;

  factory YamlEditor(String yaml,
          {YamlStyle defaultStyle = const YamlStyle()}) =>
      YamlStringEditor(yaml, defaultStyle: defaultStyle);

  /// Parses the document to return [YamlNode] currently present at [path]. If no [YamlNode]s exist
  /// at [path], [parseAt] will return a [YamlNode]-wrapped [orElse] if it is defined, or throw an
  /// [ArgumentError] otherwise.
  ///
  /// Note that this behavior deviates slightly from standard [Map] behavior, which returns `null`
  /// instead if the key is not present.
  YamlNode parseAt(Iterable<Object> path, {Object orElse});

  /// Sets [value] in the [path].
  ///
  /// Note that [assign] provides a different result as compared to a [remove] followed by an
  /// [insertIntoList], because it preserves comments at the same level.
  ///
  /// Throws an [ArgumentError] if path is invalid, and throws the usual Dart errors otherwise (e.g.
  /// [RangeError] if [keyOrIndex] is negative or longer than list length).
  ///
  /// Users have the option of defining the indentation applied for this particular
  /// modification and whether flow structures will be applied via the optional parameter [style].
  /// For a comprehensive list of styling options, refer to the documentation for [YamlStyle].
  void assign(Iterable<Object> path, Object value, {YamlStyle style});

  /// Appends [value] into the list at [listPath].
  ///
  /// If the element at the given path is not a [YamlList] or if the path is invalid, an
  /// [ArgumentError] will be thrown.
  ///
  /// Users have the option of defining the indentation applied for this particular
  /// modification and whether flow structures will be applied via the optional parameter [style].
  /// For a comprehensive list of styling options, refer to the documentation for [YamlStyle].
  void appendToList(Iterable<Object> listPath, Object value, {YamlStyle style});

  /// Prepends [value] into the list at [listPath].
  ///
  /// If the element at the given path is not a [YamlList] or if the path is invalid, an
  /// [ArgumentError] will be thrown.
  ///
  /// Users have the option of defining the indentation applied for this particular
  /// modification and whether flow structures will be applied via the optional parameter [style].
  /// For a comprehensive list of styling options, refer to the documentation for [YamlStyle].
  void prependToList(Iterable<Object> listPath, Object value,
      {YamlStyle style});

  /// Inserts [value] into the list at [listPath], only if the element at the given path
  /// is a list.
  ///
  /// [index] must be non-negative and no greater than the list's length. If the element at
  /// the given path is not a [YamlList] or if the path is invalid, an [ArgumentError] will
  /// be thrown.
  ///
  /// Users have the option of defining the indentation applied for this particular
  /// modification and whether flow structures will be applied via the optional parameter [style].
  /// For a comprehensive list of styling options, refer to the documentation for [YamlStyle].
  void insertIntoList(Iterable<Object> listPath, int index, Object value,
      {YamlStyle style});

  /// Changes the contents of the list at [listPath] by removing [deleteCount] items at [index], and
  /// inserts [values] in-place.
  ///
  /// [index] must be non-negative and no greater than the list's length. If the element at
  /// the given path is not a [YamlList] or if the path is invalid, an [ArgumentError] will
  /// be thrown.
  Iterable<YamlNode> spliceList(Iterable<Object> listPath, int index,
      int deleteCount, Iterable<Object> values,
      {YamlStyle style});

  /// Removes the node at [path].
  ///
  /// Throws [ArgumentError] if [path] is invalid.
  YamlNode remove(Iterable<Object> path);
}

/// A concrete implementation of [YamlEditor] that uses string manipulation to effect the underlying
/// YAML in order to achieve the desired changes.
///
/// YAML parsing is supported by `package:yaml`, and modifications are performed as
/// string operations. Each time a modification takes place via one of the public
/// methods, we calculate the expected final result, and parse the result YAML string,
/// and ensure the two YAML trees match, throwing an [AssertionError] otherwise. Such a situation
/// should be extremely rare, and should only occur with degenerate formatting.
class YamlStringEditor implements YamlEditor {
  /// List of [SourceEdit]s that have been applied to [_yaml] since the creation of this
  /// instance, in chronological order. Intended to be compatible with `package:analysis_server`.
  final List<SourceEdit> _edits = [];

  @override
  UnmodifiableListView<SourceEdit> get edits =>
      UnmodifiableListView<SourceEdit>([..._edits]);

  /// Current YAML string.
  String _yaml;

  /// Root node of YAML AST.
  YamlNode _contents;

  @override
  String toString() => _yaml;

  /// Style configuration settings for [YamlEditor] when modifying the YAML string.
  @override
  final YamlStyle defaultStyle;

  YamlStringEditor(this._yaml, {this.defaultStyle = const YamlStyle()}) {
    _contents = loadYamlNode(_yaml);
  }

  /// Parses the document to return [YamlNode] currently present at [path]. If no [YamlNode]s exist
  /// at [path], [parseAt] will return a [YamlNode]-wrapped [orElse] if it is defined, or throw an
  /// [ArgumentError] otherwise.
  ///
  /// Note that this behavior deviates slightly from standard [Map] behavior, which returns `null`
  /// instead if the key is not present.
  ///
  /// Common usage example:
  /// ```dart
  ///   final doc = YamlEditor('''
  /// a: 1
  /// b:
  ///   d: 4
  ///   e: [5, 6, 7]
  /// c: 3
  /// ''');
  /// print(doc.parseAt(['b', 'e', 2])); // 7
  /// ```
  ///
  /// To illustrate that [parseAt] returns a [YamlNode] that can be invalidated if modifications are
  /// performed to the document,
  /// ```dart
  /// final doc = YamlEditor("YAML: YAML Ain't Markup Language");
  /// final node = doc.parseAt(['YAML']);
  ///
  /// print(node.value); // Expected output: "YAML Ain't Markup Language"
  ///
  /// doc.setIn(['YAML'], 'YAML');
  ///
  /// final newNode = doc.parseAt(['YAML']);
  ///
  /// // Note that the value does not change
  /// print(newNode.value); // "YAML"
  /// print(node.value); // "YAML Ain't Markup Language"
  /// ```
  ///
  /// Ensuring that you get the value you want:
  /// ```dart
  /// final doc = YamlEditor('{a: {d: 4}, c: ~}');
  /// doc.parseAt(['b', 'd']); // ArgumentError
  /// doc.parseAt(['b']); // ArgumentError
  /// doc.parseAt(['b'], orElse: null); // YamlScalar(null)
  /// doc.parseAt(['b'], orElse: {"a": 42}); // YamlMap({"a": 42})
  /// doc.parseAt(['b'], orElse: 42); // YamlScalar(42)
  ///
  /// final doc2 = YamlEditor('[0,1]');
  /// doc2.parseAt([2]); // ArgumentError
  /// doc2.parseAt(["2"]); // ArgumentError
  /// ```
  ///
  /// [orElse] can also be used to determine if a path exists.
  /// ```dart
  /// doc.parseAt(my_path, orElse: #doesNotExist);
  ///
  /// // Or, if you know that your collection will not contain booleans,
  /// doc.parseAt(my_path, orElse: false);
  /// ```
  @override
  YamlNode parseAt(Iterable<Object> path, {Object orElse = #noArg}) {
    try {
      return _traverse(path);
    } on ArgumentError {
      if (orElse == #noArg) {
        rethrow;
      } else {
        if (orElse is YamlNode) {
          return orElse;
        }

        return yamlNodeFrom(orElse);
      }
    }
  }

  /// Sets [value] in the [path], with an optional [style] parameter applied to only this modification.
  ///
  /// Note that [assign] provides a different result as compared to a [remove] followed by an
  /// [insertIntoList], because it preserves comments at the same level.
  ///
  /// Throws an [ArgumentError] if path is invalid, and throws the usual Dart errors otherwise (e.g.
  /// [RangeError] if [keyOrIndex] is negative or longer than list length).
  ///
  /// Users have the option of defining the indentation applied for this particular
  /// modification and whether flow structures will be applied via the optional parameter [style].
  /// For a comprehensive list of styling options, refer to the documentation for [YamlStyle].
  ///
  /// ```dart
  /// final doc = YamlEditor('''
  ///   - 0
  ///   - 1 # comment
  ///   - 2
  /// ''');
  /// doc.assign([1], 'test');
  /// ```
  ///
  /// Expected Output:
  /// ```yaml
  ///   - 0
  ///   - test # comment
  ///   - 2
  /// ```
  ///
  /// ```dart
  /// final doc2 = YamlEditor("[YAML Ain't Markup Language   # comment]");
  /// doc2.removeIn([1]);
  /// doc2.insertIntoList([1], 'test');
  /// ```
  ///
  /// Expected Output:
  /// '''
  ///   - 0
  ///   - test
  ///   - 2
  /// '''
  @override
  void assign(Iterable<Object> path, Object value, {YamlStyle style}) {
    if (path.isEmpty) {
      final end = getContentSensitiveEnd(_contents);
      final edit = SourceEdit(0, end, getFlowString(value));

      _performEdit(edit, path, yamlNodeFrom(value));
      return;
    }

    final collectionPath = path.take(path.length - 1);
    final keyOrIndex = path.last;
    final parentNode = parseAt(collectionPath);

    var edit;
    var expectedNode;

    final valueNode = yamlNodeFrom(value);

    style ??= defaultStyle;

    if (parentNode is YamlList) {
      edit = assignInList(_yaml, parentNode, keyOrIndex, value, style);
      expectedNode =
          updatedYamlList(parentNode, (nodes) => nodes[keyOrIndex] = valueNode);
    } else if (parentNode is YamlMap) {
      edit = assignInMap(_yaml, parentNode, keyOrIndex, value, style);
      final keyNode = yamlNodeFrom(keyOrIndex);
      expectedNode =
          updatedYamlMap(parentNode, (nodes) => nodes[keyNode] = valueNode);
    } else {
      throw ArgumentError('Scalar $parentNode does not have key $keyOrIndex');
    }

    _performEdit(edit, collectionPath, expectedNode);
  }

  /// Appends [value] into the list at [listPath].
  ///
  /// If the element at the given path is not a [YamlList] or if the path is invalid, an
  /// [ArgumentError] will be thrown.
  ///
  /// Users have the option of defining the indentation applied for this particular
  /// modification and whether flow structures will be applied via the optional parameter [style].
  /// For a comprehensive list of styling options, refer to the documentation for [YamlStyle].
  @override
  void appendToList(Iterable<Object> listPath, Object value,
      {YamlStyle style}) {
    var yamlList = _traverseToList(listPath);

    insertIntoList(listPath, yamlList.length, value, style: style);
  }

  /// Prepends [value] into the list at [listPath].
  ///
  /// If the element at the given path is not a [YamlList] or if the path is invalid, an
  /// [ArgumentError] will be thrown.
  ///
  /// Users have the option of defining the indentation applied for this particular
  /// modification and whether flow structures will be applied via the optional parameter [style].
  /// For a comprehensive list of styling options, refer to the documentation for [YamlStyle].
  @override
  void prependToList(Iterable<Object> listPath, Object value,
          {YamlStyle style}) =>
      insertIntoList(listPath, 0, value, style: style);

  /// Inserts [value] into the list at [listPath], only if the element at the given path
  /// is a list.
  ///
  /// [index] must be non-negative and no greater than the list's length. If the element at
  /// the given path is not a [YamlList] or if the path is invalid, an [ArgumentError] will
  /// be thrown.
  ///
  /// Users have the option of defining the indentation applied for this particular
  /// modification and whether flow structures will be applied via the optional parameter [style].
  /// For a comprehensive list of styling options, refer to the documentation for [YamlStyle].
  @override
  void insertIntoList(Iterable<Object> listPath, int index, Object value,
      {YamlStyle style}) {
    style ??= defaultStyle;

    var list = _traverseToList(listPath);
    final edit = insertInList(_yaml, list, index, value, style);

    final expectedList = updatedYamlList(
        list, (nodes) => nodes.insert(index, yamlNodeFrom(value)));

    _performEdit(edit, listPath, expectedList);
  }

  /// Changes the contents of the list at [listPath] by removing [deleteCount] items at [index], and
  /// inserts [values] in-place.
  ///
  /// [index] must be non-negative and no greater than the list's length. If the element at
  /// the given path is not a [YamlList], if the path is invalid, or if [index] + [deleteCount]
  /// is greater than the list length, an [ArgumentError] will be thrown.
  ///
  /// ```dart
  /// final doc = YamlEditor('[Jan, March, April, June]');
  /// doc.spliceList([], 1, 0, ['Feb']); // [Jan, Feb, March, April, June]
  /// doc.spliceList([], 4, 1, ['May']); // [Jan, Feb, March, April, May]
  /// ```
  @override
  Iterable<YamlNode> spliceList(Iterable<Object> listPath, int index,
      int deleteCount, Iterable<Object> values,
      {YamlStyle style}) {
    style ??= defaultStyle;
    var list = _traverseToList(listPath);

    final nodesToRemove = list.nodes.getRange(index, index + deleteCount);

    /// Perform addition of elements before removal to avoid scenarioes where
    /// a block list gets emptied out to {} to avoid changing collection styles
    /// where possible.

    /// Reverse [values] and insert them.
    final reversedValues = values.toList().reversed;
    for (var value in reversedValues) {
      insertIntoList(listPath, index, value, style: style);
    }

    for (var i = 0; i < deleteCount; i++) {
      remove([...listPath, index + values.length]);
    }

    return nodesToRemove;
  }

  /// Removes the node at [path].
  ///
  /// Throws [ArgumentError] if [path] is invalid.
  @override
  YamlNode remove(Iterable<Object> path) {
    var edit;
    var expectedNode;
    var nodeToRemove = parseAt(path);

    if (path.isEmpty) {
      expectedNode = null;
      edit = SourceEdit(0, _yaml.length, '');

      _performEdit(edit, path, expectedNode);
    } else {
      final collectionPath = path.take(path.length - 1);
      final keyOrIndex = path.last;
      final parentNode = parseAt(collectionPath);

      if (parentNode is YamlList) {
        edit = removeInList(_yaml, parentNode, keyOrIndex);
        expectedNode =
            updatedYamlList(parentNode, (nodes) => nodes.removeAt(keyOrIndex));
      } else if (parentNode is YamlMap) {
        edit = removeInMap(_yaml, parentNode, keyOrIndex);

        expectedNode =
            updatedYamlMap(parentNode, (nodes) => nodes.remove(keyOrIndex));
      }

      _performEdit(edit, collectionPath, expectedNode);
    }

    return nodeToRemove;
  }

  /// Traverses down [path] to return the [YamlNode] at [path] if successful, throwing an
  /// [ArgumentError] otherwise.
  YamlNode _traverse(Iterable<Object> path) {
    if (path.isEmpty) {
      return _contents;
    }

    var currentNode = _contents;

    for (var keyOrIndex in path) {
      if (currentNode is YamlList) {
        final list = currentNode as YamlList;
        if (isValidIndex(keyOrIndex, list.length)) {
          currentNode = list.nodes[keyOrIndex];
        } else {
          throw ArgumentError(
              'List $list does not take index $keyOrIndex from path $path');
        }
      } else if (currentNode is YamlMap) {
        final map = currentNode as YamlMap;

        if (containsKey(map, keyOrIndex)) {
          currentNode = map.nodes[keyOrIndex];
        } else {
          throw ArgumentError(
              'Map $map does not have key $keyOrIndex from path $path');
        }
      } else {
        throw ArgumentError(
            'Unable to traverse to $keyOrIndex in path $path from scalar $currentNode');
      }
    }

    return currentNode;
  }

  /// Traverses down the provided [path] to return the [YamlList] at [path] if successful,
  /// throwing an [ArgumentError] otherwise.
  ///
  /// Convenience function to ensure that a [YamlList] is returned.
  YamlList _traverseToList(Iterable<Object> path) {
    final possibleList = parseAt(path);

    if (possibleList is YamlList) {
      return possibleList;
    } else {
      throw ArgumentError('Path $path does not point to a YamlList!');
    }
  }

  /// Utility method to replace the substring of [_yaml] according to [edit].
  ///
  /// When [_yaml] is modified with this method, the resulting string is parsed
  /// and reloaded and traversed down [path] to ensure that the reloaded YAML tree
  /// is equal to our expectations by deep equality of values. Throws an
  /// [AssertionError] if the two trees do not match.
  void _performEdit(
      SourceEdit edit, Iterable<Object> path, YamlNode expectedNode) {
    final expectedTree = _deepModify(_contents, path, expectedNode);
    _yaml = edit.apply(_yaml);
    final actualTree = loadYamlNode(_yaml);

    if (!deepEquals(actualTree, expectedTree)) {
      throw AssertionError('''
Modification did not result in expected result! 
Obtained: 
$actualTree
Expected: 
$expectedTree''');
    }

    _contents = actualTree;
    _edits.add(edit);
  }

  /// Utility method to produce an updated YAML tree equivalent to converting the [YamlNode]
  /// at [path] to be [expectedNode].
  ///
  /// Throws an [ArgumentError] if path is invalid.
  ///
  /// When called, it creates a new [YamlNode] of the same type as [tree], and copies its children
  /// over, except for the child that is on the path. Doing so allows us to "update" the immutable
  /// [YamlNode] without having to clone the whole tree.
  ///
  /// [SourceSpan]s in this new tree are not guaranteed to be accurate.
  YamlNode _deepModify(
      YamlNode tree, Iterable<Object> path, YamlNode expectedNode) {
    if (path.isEmpty) return expectedNode;

    final nextPath = path.skip(1);

    if (tree is YamlList) {
      final index = path.first;

      if (!isValidIndex(index, tree.length)) {
        throw ArgumentError('List $tree does not take index $index');
      }

      return updatedYamlList(
          tree,
          (nodes) =>
              nodes[index] = _deepModify(nodes[index], nextPath, expectedNode));
    } else if (tree is YamlMap) {
      final key = path.first;
      final keyNode = yamlNodeFrom(key);
      return updatedYamlMap(
          tree,
          (nodes) => nodes[keyNode] =
              _deepModify(nodes[keyNode], nextPath, expectedNode));
    } else {
      throw ArgumentError('Unable to perform _deepModify on scalar $tree');
    }
  }
}
