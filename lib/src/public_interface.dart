import 'package:yaml/yaml.dart';

import './source_edit.dart';

/// An interface for modififying [YAML][1] documents while preserving comments and
/// whitespaces.
///
/// YAML parsing is supported by `package:yaml`, and modifications are performed as
/// string operations. Each time a modification takes place via one of the public
/// methods, we calculate the expected final result, and parse the result YAML string,
/// and ensure the two YAML trees match, throwing an exception otherwise. Such a situation
/// should be extremely rare, and should only occur with degenerate formatting.
///
/// Users may define the default settings to be applied to these string modifications.
/// Note however that these settings only apply to portions of the YAML that are modified
/// by this class.
///
/// Most modification methods require the user to pass in an [Iterable<Object>] path that
/// holds the keys/indices to navigate to the element. Key equality is performed via
/// `package:yaml`'s [YamlMap]'s key equality.
///
/// [1]: https://yaml.org/
abstract class YamlEditor {
  /// The configuration to be used for the various string manipulation operations.
  final YamlStyle config;

  /// List of [SourceEdit]s that have been applied to [_yaml] since the creation of this
  /// instance, in chronological order. Intended to be compatible with `package:analysis_server`.
  final List<SourceEdit> edits = [];

  YamlEditor(String yaml, {this.config = const YamlStyle()});

  /// Returns the current YAML string after the various modifications.
  @override
  String toString();

  /// Returns the [YamlNode] present at the path. The [YamlNode] that is returned represents
  /// the current value when the function is called, and will not be updated when the YAML
  /// is updated in the future. For example,
  ///
  /// ```dart
  /// final node = doc.parseValueAt(['YAML']);
  ///
  /// print(node.value); /// Expected output: "YAML Ain't Markup Language"
  ///
  /// doc.setIn(['YAML'], 'YAML');
  ///
  /// final newNode = doc.parseValueAt(['YAML']);
  ///
  /// print(newNode.value); /// "YAML"
  /// print(node.value); /// "YAML Ain't Markup Language"
  /// ```
  ///
  /// An [ArgumentError] will be thrown if calling the `[]` operator would have resulted in an
  /// error, but `null` (as opposed to [YamlScalar] null) will be returned if the operation would
  /// have resulted in a `null` value on a dart collection.
  ///
  /// ```dart
  /// final doc = YamlEditor('{a: {d: 4}, c: ~}');
  /// doc.parseValueAt(['b', 'd']); // ArgumentError
  /// doc.parseValueAt(['b']); // null
  /// doc.parseValueAt(['c']); // YamlScalar(null)
  ///
  /// final doc2 = YamlEditor('[0,1]');
  /// doc2.parseValueAt([2]); // ArgumentError
  /// doc2.parseValueAt(["2"]); // ArgumentError
  /// ```
  YamlNode parseValueAt(Iterable<Object> path, {Object Function() orElse});

  /// Sets [value] in the [path]. Takes an optional [style] parameter.
  ///
  /// If the [path] is not accessible (e.g. it currently does not exist in the document),
  /// an error will be thrown. Note that [setIn] provides a different result as compared to
  /// a [removeIn] followed by an [insertIn], because it preserves comments at the same level.
  ///
  /// ```dart
  /// final doc = YamlEditor('''
  ///   - 0
  ///   - 1 # comment
  ///   - 2
  /// ''');
  /// doc.setIn([1], 'test');
  /// ```
  ///
  /// Expected Output:
  /// '''
  ///   - 0
  ///   - test # comment
  ///   - 2
  /// '''
  ///
  /// ```dart
  /// final doc2 = YamlEditor("[YAML Ain't Markup Language   # comment]");
  /// doc2.removeIn([1]);
  /// doc2.insertInList([1], 'test');
  /// ```
  ///
  /// Expected Output:
  /// '''
  ///   - 0
  ///   - test
  ///   - 2
  /// '''
  void setIn(Iterable<Object> path, {YamlStyle style});

  /// Removes the value in the path.
  void removeIn(Iterable<Object> path);

  /// Appends [value] into the list at [listPath], only if the element at the given path
  /// is a List.
  ///
  /// Users have the option of defining the indentation applied and whether
  /// flow structures will be applied via the optional parameter [style]. For a comprehensive
  /// list of styling options, refer to the documentation for [YamlStyle].
  ///
  /// **Convenience Method**
  /// [addInList] is equivalent to [insertInList] with index = length.
  void addInList(Iterable<Object> listPath, Object value,
      {YamlStyle yamlStyle});

  /// Prepends [value] into the list at [listPath], only if the element at the given path
  /// is a List.
  ///
  /// Users have the option of defining the indentation applied and whether
  /// flow structures will be applied via the optional parameter [style]. For a comprehensive
  /// list of styling options, refer to the documentation for [YamlStyle].
  ///
  /// **Convenience Method**
  /// [prependInList] is equivalent to [insertInList] with index = 0.
  void prependInList(Iterable<Object> listPath, Object value,
      {YamlStyle yamlStyle});

  /// Inserts [value] into the list at [listPath], only if the element at the given path
  /// is a list. [index] must be non-negative and no greater than the list's length.
  ///
  /// Users have the option of defining the indentation applied and whether
  /// flow structures will be applied via the optional parameter [style]. For a comprehensive
  /// list of styling options, refer to the documentation for [YamlStyle].
  void insertInList(Iterable<Object> listPath, int index, Object value,
      {YamlStyle yamlStyle});

  /// Checks if a given [path] exists in the YAML.
  bool pathExists(Iterable<Object> path);
}

/// Style configuration settings for [YamlEditor] when modifying the YAML string.
class YamlStyle {
  /// The number of additional spaces from the starting column between block YAML elements
  /// of adjacent levels.
  final int indentationStep;

  /// Enforce flow structures when adding or modifying values. If this value is false,
  /// we try to make collections in block style where possible.
  final bool enforceFlow;

  const YamlStyle({this.indentationStep = 2, this.enforceFlow = false});

  /// Creates a new [YamlStyle] with the same configuration options as before, except for
  /// the properties specified in arguments.
  YamlStyle withOpts({int indentStep, bool useFlow}) {
    indentStep ??= indentationStep;
    useFlow ??= enforceFlow;

    return YamlStyle(indentationStep: indentStep, enforceFlow: useFlow);
  }
}
