import 'package:yaml/src/equality.dart';
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
class YamlEditor {
  /// List of [SourceEdit]s that have been applied to [_yaml] since the creation of this
  /// instance, in chronological order. Intended to be compatible with `package:analysis_server`.
  final List<SourceEdit> edits = [];

  /// Current YAML string.
  String _yaml;

  /// Root node of YAML AST.
  YamlNode _contents;

  /// Style configuration settings for [YamlEditor] when modifying the YAML string.
  final YamlStyle defaultStyle;

  @override
  String toString() => _yaml;

  YamlEditor(this._yaml, {this.defaultStyle = const YamlStyle()}) {
    _contents = loadYamlNode(_yaml);
  }

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
  YamlNode parseValueAt(Iterable<Object> path) {
    dynamic current = _contents;

    for (var key in path) {
      try {
        current = current.nodes[key];
      } catch (Error) {
        throw ArgumentError(
            'Invalid path $path: Invalid key $key supplied to $current');
      }
    }

    return current;
  }

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
  void setIn(Iterable<Object> path, Object value, {YamlStyle style}) {
    final collectionPath = path.take(path.length - 1);
    final maybeCollection = parseValueAt(collectionPath);
    final lastNode = path.last;

    var edit;
    var expectedNode;

    final valueNode = _yamlNodeFrom(value);

    style ??= defaultStyle;

    if (maybeCollection is YamlList) {
      edit = _setInList(_yaml, maybeCollection, lastNode, value, style);
      expectedNode = _updatedYamlList(
          maybeCollection, (nodes) => nodes[lastNode] = valueNode);
    } else if (maybeCollection is YamlMap) {
      edit = _setInMap(_yaml, maybeCollection, lastNode, value, style);
      final keyNode = _yamlNodeFrom(lastNode);
      expectedNode = _updatedYamlMap(
          maybeCollection, (nodes) => nodes[keyNode] = valueNode);
    } else {
      throw ArgumentError(
          'Scalar $maybeCollection does not have key $lastNode');
    }

    _performEdit(edit, collectionPath, expectedNode);
  }

  /// Appends [value] into the list at [listPath], only if the element at the given path
  /// is a [YamlList].
  ///
  /// Users have the option of defining the indentation applied and whether
  /// flow structures will be applied via the optional parameter [style]. For a comprehensive
  /// list of styling options, refer to the documentation for [YamlStyle].
  void addInList(Iterable<Object> listPath, Object value,
      {YamlStyle yamlStyle}) {
    var style = defaultStyle;
    if (yamlStyle != null) style = yamlStyle;

    final yamlList = _traverseToList(listPath);
    final edit = _addToList(_yaml, yamlList, value, style);

    final expectedList =
        _updatedYamlList(yamlList, (nodes) => nodes.add(_yamlNodeFrom(value)));

    _performEdit(edit, listPath, expectedList);
  }

  /// Prepends [value] into the list at [listPath], only if the element at the given path
  /// is a [YamlList].
  ///
  /// Users have the option of defining the indentation applied and whether
  /// flow structures will be applied via the optional parameter [style]. For a comprehensive
  /// list of styling options, refer to the documentation for [YamlStyle].
  void prependInList(Iterable<Object> listPath, Object value,
          {YamlStyle style}) =>
      insertInList(listPath, 0, value, style: style);

  /// Inserts [value] into the list at [listPath], only if the element at the given path
  /// is a list. [index] must be non-negative and no greater than the list's length.
  ///
  /// Users have the option of defining the indentation applied and whether
  /// flow structures will be applied via the optional parameter [style]. For a comprehensive
  /// list of styling options, refer to the documentation for [YamlStyle].
  void insertInList(Iterable<Object> listPath, int index, Object value,
      {YamlStyle style}) {
    style ??= defaultStyle;

    var yamlList = _traverseToList(listPath);
    final edit = _insertInList(_yaml, yamlList, index, value, style);

    final expectedList = _updatedYamlList(
        yamlList, (nodes) => nodes.insert(index, _yamlNodeFrom(value)));

    _performEdit(edit, listPath, expectedList);
  }

  /// Removes the node at the [path].
  void removeIn(Iterable<Object> path) {
    final collectionPath = path.take(path.length - 1);
    final current = parseValueAt(collectionPath);
    final lastNode = path.last;

    var edit;
    var expectedNode;

    if (current is YamlList) {
      edit = _removeInList(_yaml, current, lastNode);
      expectedNode =
          _updatedYamlList(current, (nodes) => nodes.removeAt(lastNode));
    } else if (current is YamlMap) {
      edit = _removeInMap(_yaml, current, lastNode);

      final keyNode = _getKeyNode(current, lastNode);
      expectedNode = _updatedYamlMap(current, (nodes) => nodes.remove(keyNode));
    } else {
      throw TypeError();
    }

    _performEdit(edit, collectionPath, expectedNode);
  }

  /// Traverses down the provided [path] to the [YamlList] at [path].
  ///
  /// Convenience function to ensure that a [YamlList] is returned.
  YamlList _traverseToList(Iterable<Object> path) {
    final possibleList = parseValueAt(path);

    if (possibleList is YamlList) {
      return possibleList;
    } else {
      throw TypeError();
    }
  }

  /// Utility method to replace the substring of [_yaml] according to [edit].
  ///
  ///
  /// When [_yaml] is modified with this method, the resulting string is parsed
  /// and reloaded and traversed down [path] to ensure that the reparsed node is
  /// equal to [expectedNode] using `package:yaml`'s deep equality.
  void _performEdit(
      SourceEdit edit, Iterable<Object> path, YamlNode expectedNode) {
    _yaml = edit.apply(_yaml);
    _contents = loadYamlNode(_yaml);
    final actualNode = parseValueAt(path);

    if (!deepEquals(actualNode, expectedNode)) {
      throw Exception('''
Modification did not result in expected result! 
Obtained: 
$actualNode
Expected: 
$expectedNode''');
    }

    edits.add(edit);
  }
}

/// Performs the string operation on [yaml] to achieve the effect of setting
/// the element at [index] to [newValue] when re-parsed.
SourceEdit _setInList(
    String yaml, YamlList list, int index, Object newValue, YamlStyle style) {
  final currValue = list.nodes[index];

  final offset = currValue.span.start.offset;
  final length = currValue.span.end.offset - offset;

  return SourceEdit(offset, length, newValue.toString());
}

/// Performs the string operation on [yaml] to achieve the effect of removing
/// the element at [index] when re-parsed.
///
/// Returns the node that is removed.
SourceEdit _removeInList(String yaml, YamlList list, int index) {
  final nodeToRemove = list.nodes[index];

  if (list.style == CollectionStyle.FLOW) {
    return _removeFromFlowList(yaml, list, nodeToRemove, index);
  } else {
    return _removeFromBlockList(yaml, list, nodeToRemove, index);
  }
}

/// Performs the string operation on [yaml] to achieve the effect of
/// removing [elem] when re-parsed.
///
/// Returns `true` if [elem] was successfully found and removed, `false` otherwise.
SourceEdit _removeFromList(String yaml, YamlList list, Object elem) {
  var index = _indexOf(list, elem);
  if (index == -1) return null;

  return _removeInList(yaml, list, index);
}

/// Performs the string operation on [yaml] to achieve the effect of
/// appending [elem] to the list.
SourceEdit _addToList(
    String yaml, YamlList list, Object elem, YamlStyle style) {
  if (list.style == CollectionStyle.FLOW) {
    return _addToFlowList(yaml, list, elem, style);
  } else {
    return _addToBlockList(yaml, list, elem, style);
  }
}

/// Performs the string operation on [yaml] to achieve a similar effect of
/// inserting [elem] to the list at [index].
SourceEdit _insertInList(
    String yaml, YamlList list, int index, Object elem, YamlStyle style) {
  if (index > list.length || index < 0) {
    throw RangeError.range(index, 0, list.length);
  }

  /// We call the add method if the user wants to add it to the end of the list
  /// because appending requires different techniques.
  if (index == list.length) {
    return _addToList(yaml, list, elem, style);
  } else if (index == 0) {
    if (list.style == CollectionStyle.FLOW) {
      return _prependToFlowList(yaml, list, elem, style);
    } else {
      return _prependToBlockList(yaml, list, elem, style);
    }
  } else {
    if (list.style == CollectionStyle.FLOW) {
      return _insertInFlowList(yaml, list, index, elem, style);
    } else {
      return _insertInBlockList(yaml, list, index, elem, style);
    }
  }
}

/// Gets the indentation level of the list. This is 0 if it is a flow list,
/// but returns the number of spaces before the hyphen of elements for
/// block lists.
int _getListIndentation(String yaml, YamlList list) {
  if (list.style == CollectionStyle.FLOW) return 0;

  if (list.nodes.isEmpty) {
    throw UnsupportedError('Unable to get indentation for empty block list');
  }

  final lastSpanOffset = list.nodes.last.span.start.offset;
  var lastNewLine = yaml.lastIndexOf('\n', lastSpanOffset);
  if (lastNewLine == -1) lastNewLine = 0;
  final lastHyphen = yaml.lastIndexOf('-', lastSpanOffset);

  return lastHyphen - lastNewLine - 1;
}

/// Returns a new [YamlList] constructed by applying [update] onto the [nodes]
/// of this [YamlList].
YamlList _updatedYamlList(YamlList list, Function(List<YamlNode>) update) {
  final newNodes = [...list.nodes];
  update(newNodes);
  return _yamlNodeFrom(newNodes);
}

/// Performs the string operation on [yaml] to achieve the effect of removing
/// [nodeToRemove] from [nodes], noting that this is a flow list.
SourceEdit _removeFromFlowList(
    String yaml, YamlList list, YamlNode nodeToRemove, int index) {
  final span = nodeToRemove.span;
  var start = span.start.offset;
  var end = span.end.offset;

  if (index == 0) {
    start = yaml.lastIndexOf('[', start) + 1;
    end = yaml.indexOf(RegExp(r',|]'), end) + 1;
  } else {
    start = yaml.lastIndexOf(',', start);
  }

  return SourceEdit(start, end - start, '');
}

/// Performs the string operation on [yaml] to achieve the effect of removing
/// [nodeToRemove] from [nodes], noting that this is a block list.
SourceEdit _removeFromBlockList(
    String yaml, YamlList list, YamlNode removedNode, int index) {
  final span = removedNode.span;
  var start = yaml.lastIndexOf('\n', span.start.offset);
  var end = yaml.indexOf('\n', span.end.offset);

  if (start == -1) start = 0;
  if (end == -1) end = yaml.length;

  return SourceEdit(start, end - start, '');
}

/// Returns the index of [element] in the list if present, or -1 if it is absent.
int _indexOf(YamlList list, Object element) {
  for (var i = 0; i < list.length; i++) {
    if (deepEquals(list[i].value, element)) return i;
  }
  return -1;
}

/// Performs the string operation on [yaml] to achieve the effect of prepending
/// [elem] into [nodes], noting that this is a flow list.
SourceEdit _prependToFlowList(
    String yaml, YamlList list, Object elem, YamlStyle style) {
  var valueString = _getFlowString(elem);
  if (list.nodes.isNotEmpty) valueString = '$valueString, ';

  return SourceEdit(list.span.start.offset + 1, 0, valueString);
}

/// Performs the string operation on [yaml] to achieve the effect of prepending
/// [elem] into [nodes], noting that this is a block list.
SourceEdit _prependToBlockList(
    String yaml, YamlList list, Object elem, YamlStyle style) {
  final valueString = _getBlockString(
      elem, _getListIndentation(yaml, list) + style.indentationStep);
  var formattedValue = ''.padLeft(_getListIndentation(yaml, list)) + '- ';

  if (_isCollection(elem)) {
    formattedValue += valueString.substring(
            _getListIndentation(yaml, list) + style.indentationStep) +
        '\n';
  } else {
    formattedValue += valueString + '\n';
  }

  final startOffset = yaml.lastIndexOf('\n', list.span.start.offset) + 1;

  return SourceEdit(startOffset, 0, formattedValue);
}

/// Performs the string operation on [yaml] to achieve the effect of insertion
/// [elem] into [nodes] at [index], noting that this is a flow list. [index] should
/// be non-negative and less than or equal to [length].
SourceEdit _insertInFlowList(
    String yaml, YamlList list, int index, Object elem, YamlStyle style) {
  if (index == list.length) return _addToFlowList(yaml, list, elem, style);
  if (index == 0) return _prependToFlowList(yaml, list, elem, style);

  var valueString = ' ' + _getFlowString(elem);
  if (list.nodes.isNotEmpty) valueString = '$valueString,';

  final currNode = list.nodes[index];
  final currNodeStartIdx = currNode.span.start.offset;
  final startOffset = yaml.lastIndexOf(RegExp(r',|\['), currNodeStartIdx) + 1;

  return SourceEdit(startOffset, 0, valueString);
}

/// Performs the string operation on [yaml] to achieve the effect of insertion
/// [elem] into [nodes] at [index], noting that this is a block list. [index] should
/// be non-negative and less than or equal to [length].
SourceEdit _insertInBlockList(
    String yaml, YamlList list, int index, Object elem, YamlStyle style) {
  if (index == list.length) {
    return _addToBlockList(yaml, list, elem, style);
  }
  if (index == 0) return _prependToBlockList(yaml, list, elem, style);

  final valueString = _getBlockString(
      elem, _getListIndentation(yaml, list) + style.indentationStep);
  var formattedValue = ''.padLeft(_getListIndentation(yaml, list)) + '- ';

  if (_isCollection(elem)) {
    formattedValue += valueString.substring(
            _getListIndentation(yaml, list) + style.indentationStep) +
        '\n';
  } else {
    formattedValue += valueString + '\n';
  }

  final currNode = list.nodes[index];
  final currNodeStartIdx = currNode.span.start.offset;
  final startOffset = yaml.lastIndexOf('\n', currNodeStartIdx) + 1;

  return SourceEdit(startOffset, 0, formattedValue);
}

/// Performs the string operation on [yaml] to achieve the effect of addition
/// [elem] into [nodes], noting that this is a flow list.
SourceEdit _addToFlowList(
    String yaml, YamlList list, Object elem, YamlStyle style) {
  var valueString = _getFlowString(elem);
  if (list.nodes.isNotEmpty) valueString = ', ' + valueString;

  return SourceEdit(list.span.end.offset - 1, 0, valueString);
}

/// Performs the string operation on [yaml] to achieve the effect of addition
/// [elem] into [nodes], noting that this is a
/// block list.
SourceEdit _addToBlockList(
    String yaml, YamlList list, Object elem, YamlStyle style) {
  final valueString = _getBlockString(
      elem, _getListIndentation(yaml, list) + style.indentationStep);
  var formattedValue = ''.padLeft(_getListIndentation(yaml, list)) + '- ';

  if (_isCollection(elem)) {
    formattedValue += valueString.substring(
            _getListIndentation(yaml, list) + style.indentationStep) +
        '\n';
  } else {
    formattedValue += valueString + '\n';
  }

  // Adjusts offset to after the trailing newline of the last entry, if it exists
  if (list.nodes.isNotEmpty) {
    final lastValueSpanEnd = list.nodes.last.span.end.offset;
    final nextNewLineIndex = yaml.indexOf('\n', lastValueSpanEnd);
    if (nextNewLineIndex == -1) {
      formattedValue = '\n' + formattedValue;
    }
  }

  return SourceEdit(list.span.end.offset, 0, formattedValue);
}

/// Performs the string operation on [yaml] to achieve the effect of setting
/// the element at [key] to [newValue] when re-parsed.
SourceEdit _setInMap(
    String yaml, YamlMap map, Object key, Object newValue, YamlStyle style) {
  if (!map.nodes.containsKey(key)) {
    if (map.style == CollectionStyle.FLOW) {
      return _addToFlowMap(yaml, map, key, newValue, style);
    } else {
      return _addToBlockMap(yaml, map, key, newValue, style);
    }
  } else {
    if (map.style == CollectionStyle.FLOW) {
      return _replaceInFlowMap(yaml, map, key, newValue, style);
    } else {
      return _replaceInBlockMap(yaml, map, key, newValue, style);
    }
  }
}

/// Performs the string operation on [yaml] to achieve the effect of removing
/// the element at [key] to [newValue] when re-parsed.
///
/// Returns the [YamlNode] removed.
SourceEdit _removeInMap(String yaml, YamlMap map, Object key) {
  if (!map.nodes.containsKey(key)) return null;

  final keyNode = _getKeyNode(map, key);
  final valueNode = map.nodes[key];

  if (map.style == CollectionStyle.FLOW) {
    return _removeFromFlowMap(yaml, map, keyNode, valueNode);
  } else {
    return _removeFromBlockMap(yaml, map, keyNode, valueNode);
  }
}

/// Returns the [YamlNode] corresponding to the provided [key].
YamlNode _getKeyNode(YamlMap map, Object key) {
  return (map.nodes.keys.firstWhere((node) => deepEquals(node, key))
      as YamlNode);
}

/// Gets the indentation level of the map. This is 0 if it is a flow map,
/// but returns the number of spaces before the keys for block maps.
int _getMapIndentation(String yaml, YamlMap map) {
  if (map.style == CollectionStyle.FLOW) return 0;

  if (map.nodes.isEmpty) {
    throw UnsupportedError('Unable to get indentation for empty block list');
  }

  final lastKey = map.nodes.keys.last as YamlNode;
  final lastSpanOffset = lastKey.span.start.offset;
  var lastNewLine = yaml.lastIndexOf('\n', lastSpanOffset);
  if (lastNewLine == -1) lastNewLine = 0;

  return lastSpanOffset - lastNewLine - 1;
}

/// Returns a new [YamlMap] constructed by applying [update] onto the [nodes]
/// of this [YamlMap].
YamlMap _updatedYamlMap(YamlMap map, Function(Map<dynamic, YamlNode>) update) {
  final dummyMap = {...map.nodes};
  update(dummyMap);

  final updatedMap = {};

  /// This workaround is necessary since `_yamlNodeFrom` will re-wrap `YamlNodes`,
  /// so we need to unwrap them before passing them in.
  for (var key in dummyMap.keys) {
    var keyValue = key.value;

    updatedMap[keyValue] = dummyMap[key];
  }

  return _yamlNodeFrom(updatedMap);
}

/// Performs the string operation on [yaml] to achieve the effect of adding
/// the [key]:[newValue] pair when reparsed, bearing in mind that this is a flow map.
SourceEdit _addToFlowMap(
    String yaml, YamlMap map, Object key, Object newValue, YamlStyle style) {
  // The -1 accounts for the closing bracket.
  if (map.nodes.isEmpty) {
    return SourceEdit(map.span.end.offset - 1, 0, '$key: $newValue');
  } else {
    return SourceEdit(map.span.end.offset - 1, 0, ', $key: $newValue');
  }
}

/// Performs the string operation on [yaml] to achieve the effect of adding
/// the [key]:[newValue] pair when reparsed, bearing in mind that this is a block map.
SourceEdit _addToBlockMap(
    String yaml, YamlMap map, Object key, Object newValue, YamlStyle style) {
  final valueString = _getBlockString(
      newValue, _getMapIndentation(yaml, map) + style.indentationStep);
  var formattedValue = ' ' * _getMapIndentation(yaml, map) + '$key: ';
  var offset = map.span.end.offset;

  // Adjusts offset to after the trailing newline of the last entry, if it exists
  if (map.nodes.isNotEmpty) {
    final lastValueSpanEnd = map.nodes.values.last.span.end.offset;
    final nextNewLineIndex = yaml.indexOf('\n', lastValueSpanEnd);

    if (nextNewLineIndex != -1) {
      offset = nextNewLineIndex + 1;
    } else {
      formattedValue = '\n' + formattedValue;
    }
  }

  if (_isCollection(newValue)) formattedValue += '\n';

  formattedValue += valueString + '\n';

  return SourceEdit(offset, 0, formattedValue);
}

/// Performs the string operation on [yaml] to achieve the effect of replacing
/// the value at [key] with [newValue] when reparsed, bearing in mind that this is a
/// flow map.

SourceEdit _replaceInFlowMap(
    String yaml, YamlMap map, Object key, Object newValue, YamlStyle style) {
  final valueSpan = map.nodes[key].span;
  var valueString = _getFlowString(newValue);

  if (_isCollection(newValue)) valueString = '\n' + valueString;

  return SourceEdit(valueSpan.start.offset,
      valueSpan.end.offset - valueSpan.start.offset, valueString);
}

/// Performs the string operation on [yaml] to achieve the effect of replacing
/// the value at [key] with [newValue] when reparsed, bearing in mind that this is a
/// block map.
SourceEdit _replaceInBlockMap(
    String yaml, YamlMap map, Object key, Object newValue, YamlStyle style) {
  final value = map.nodes[key];
  final keyNode = _getKeyNode(map, key);
  var valueString = _getBlockString(
      newValue, _getMapIndentation(yaml, map) + style.indentationStep);

  /// +2 accounts for the colon
  final start = keyNode.span.end.offset + 2;
  final end = _getContentSensitiveEnd(value);

  if (_isCollection(newValue)) valueString = '\n' + valueString;

  return SourceEdit(start, end - start, valueString);
}

/// Performs the string operation on [yaml] to achieve the effect of removing
/// the [key] from the map, bearing in mind that this is a flow map.
SourceEdit _removeFromFlowMap(
    String yaml, YamlMap map, YamlNode keyNode, YamlNode valueNode) {
  final keySpan = keyNode.span;
  final valueSpan = valueNode.span;
  var start = keySpan.start.offset;
  var end = valueSpan.end.offset;

  if (deepEquals(keyNode, map.nodes.keys.first)) {
    start = yaml.lastIndexOf('{', start) + 1;
    end = yaml.indexOf(RegExp(r',|}'), end) + 1;
  } else {
    start = yaml.lastIndexOf(',', start);
  }

  return SourceEdit(start, end - start, '');
}

/// Performs the string operation on [yaml] to achieve the effect of removing
/// the [key] from the map, bearing in mind that this is a block map.
SourceEdit _removeFromBlockMap(
    String yaml, YamlMap map, YamlNode keyNode, YamlNode valueNode) {
  var keySpan = keyNode.span;
  var valueSpan = valueNode.span;
  var start = yaml.lastIndexOf('\n', keySpan.start.offset);
  var end = yaml.indexOf('\n', valueSpan.end.offset);

  if (start == -1) start = 0;
  if (end == -1) end = yaml.length - 1;

  return SourceEdit(start, end - start, '');
}

/// Returns a safe string by checking for strings that begin with > or |
String _getSafeString(String string) {
  if (string.startsWith('>') || string.startsWith('|')) {
    return '\'$string\'';
  }

  return string;
}

/// Returns values as strings representing flow objects.
String _getFlowString(Object value) {
  return _getSafeString(value.toString());
}

/// Returns values as strings representing block objects.
// We do a join('\n') rather than having it in the mapping to avoid
// adding additional spaces when updating rather than adding elements.
String _getBlockString(Object value,
    [int indentation = 0, int additionalIndentation = 2]) {
  if (value is List) {
    return value.map((e) => ' ' * indentation + '- $e').join('\n');
  } else if (value is Map) {
    return value.entries.map((entry) {
      var result = ' ' * indentation + '${entry.key}:';

      if (!_isCollection(entry.value)) return result + ' ${entry.value}';

      return '$result\n' +
          _getBlockString(entry.value, indentation + additionalIndentation);
    }).join('\n');
  }

  return _getSafeString(value.toString());
}

/// Returns the content sensitive ending offset of a node (i.e. where the last
/// meaningful content happens)
int _getContentSensitiveEnd(YamlNode yamlNode) {
  if (yamlNode is YamlList) {
    return _getContentSensitiveEnd(yamlNode.nodes.last);
  } else if (yamlNode is YamlMap) {
    return _getContentSensitiveEnd(yamlNode.nodes.values.last);
  }

  return yamlNode.span.end.offset;
}

/// Checks if the item is a Map or a List
bool _isCollection(Object item) => item is Map || item is List;

/// Wraps [value] into a [YamlNode].
YamlNode _yamlNodeFrom(Object value) {
  if (value is Map) {
    return YamlMap.wrap(value);
  } else if (value is List) {
    return YamlList.wrap(value);
  } else {
    return YamlScalar.wrap(value);
  }
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
