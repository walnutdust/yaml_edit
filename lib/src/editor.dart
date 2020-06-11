import 'package:yaml/src/equality.dart';
import 'package:yaml/yaml.dart';

import './source_edit.dart';

/// An interface for modififying [YAML][1] documents while preserving comments and
/// whitespaces.
///
/// YAML parsing is supported by `package:yaml`, and modifications are performed as
/// string operations. Each time a modification takes place via one of the public
/// methods, we calculate the expected final result, and parse the result YAML string,
/// and ensure the two YAML trees match. Users may define the default settings to be
/// applied to these string modifications. Note however that these settings only apply
/// to portions of the YAML that are modified by this class.
///
/// [1]: https://yaml.org/
class YamlEditor {
  /// List of [SourceEdit]s that have been applied to [_yaml] since the creation of this
  /// instance, in chronological order.
  final List<SourceEdit> edits = [];

  /// Current YAML string.
  String _yaml;

  /// Root node of YAML AST.
  /// Definitely a [YamlNode], but dynamic allows us to implement both Map and List
  /// operations easily.
  dynamic _contents;

  /// The number of additional spaces from the starting column between block YAML elements
  /// of adjacent levels.
  final int indentationStep;

  @override
  String toString() => _yaml;

  YamlEditor(this._yaml, {this.indentationStep = 2}) {
    _contents = loadYamlNode(_yaml);
  }

  /// Returns the [YamlNode] present at the path. The [YamlNode] that is returned represents
  /// the current value when the function is called, and will not be updated when the YAML
  /// is updated in the future. For example,
  ///
  /// ```dart
  /// final doc = YamlEditBuilder("YAML: YAML Ain't Markup Language");
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
  YamlNode parseValueAt(Iterable<Object> path) {
    var current = _contents;

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

  /// Sets [value] in the [path].
  ///
  /// If the [path] is not accessible (e.g. it currently does not exist in the document),
  /// an error will be thrown.
  void setIn(Iterable<Object> path, Object value) {
    final collectionPath = path.take(path.length - 1);
    final yamlCollection = parseValueAt(collectionPath);
    final lastNode = path.last;

    var edit;
    var expectedNode;

    final valueNode = _yamlNodeFrom(value);

    if (yamlCollection is YamlList) {
      edit = _setInList(this, yamlCollection, collectionPath, lastNode, value);
      expectedNode = _updatedYamlList(
          yamlCollection, (nodes) => nodes[lastNode] = valueNode);
    } else if (yamlCollection is YamlMap) {
      edit = _setInMap(this, yamlCollection, collectionPath, lastNode, value);
      final keyNode = _yamlNodeFrom(lastNode);
      expectedNode = _updatedYamlMap(
          yamlCollection, (nodes) => nodes[keyNode] = valueNode);
    } else {
      throw TypeError();
    }

    _performEdit(edit, collectionPath, expectedNode);
  }

  /// Appends [value] into the list at [listPath], only if the element at the given path
  /// is a [YamlList].
  void addInList(Iterable<Object> listPath, Object value) {
    final yamlList = _traverseToList(listPath);
    final edit = _addToList(this, yamlList, listPath, value);

    final expectedList =
        _updatedYamlList(yamlList, (nodes) => nodes.add(_yamlNodeFrom(value)));

    _performEdit(edit, listPath, expectedList);
  }

  /// Prepends [value] into the list at [listPath], only if the element at the given path
  /// is a [YamlList].
  void prependInList(Iterable<Object> listPath, Object value) {
    final yamlList = _traverseToList(listPath);
    final edit = _prependToList(this, yamlList, listPath, value);

    final expectedList = _updatedYamlList(
        yamlList, (nodes) => nodes.insert(0, _yamlNodeFrom(value)));

    _performEdit(edit, listPath, expectedList);
  }

  /// Inserts [value] into the list at [listPath], only if the element at the given path
  /// is a list. [index] must be non-negative and no greater than the list's length.
  void insertInList(Iterable<Object> listPath, int index, Object value) {
    var yamlList = _traverseToList(listPath);
    final edit = _insertInList(this, yamlList, listPath, index, value);

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
      edit = _removeInList(this, current, collectionPath, lastNode);
      expectedNode =
          _updatedYamlList(current, (nodes) => nodes.removeAt(lastNode));
    } else if (current is YamlMap) {
      edit = _removeInMap(this, current, collectionPath, lastNode);

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
    _yaml = SourceEdit.applyOne(_yaml, edit);
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

/// Performs the string operation on [yamlEditor] to achieve the effect of setting
/// the element at [index] to [newValue] when re-parsed.
SourceEdit _setInList(YamlEditor yamlEditor, YamlList list,
    Iterable<Object> path, int index, Object newValue) {
  final currValue = list.nodes[index];

  final offset = currValue.span.start.offset;
  final length = currValue.span.end.offset - offset;

  return SourceEdit(offset, length, newValue.toString());
}

/// Performs the string operation on [yamlEditor] to achieve the effect of removing
/// the element at [index] when re-parsed.
///
/// Returns the node that is removed.
SourceEdit _removeInList(
    YamlEditor yamlEditor, YamlList list, Iterable<Object> path, int index) {
  final nodeToRemove = list.nodes[index];

  if (list.style == CollectionStyle.FLOW) {
    return _removeFromFlowList(yamlEditor, list, path, nodeToRemove, index);
  } else {
    return _removeFromBlockList(yamlEditor, list, path, nodeToRemove, index);
  }
}

/// Performs the string operation on [yamlEditor] to achieve the effect of
/// removing [elem] when re-parsed.
///
/// Returns `true` if [elem] was successfully found and removed, `false` otherwise.
SourceEdit _removeFromList(
    YamlEditor yamlEditor, YamlList list, Iterable<Object> path, Object elem) {
  var index = _indexOf(list, elem);
  if (index == -1) return null;

  return _removeInList(yamlEditor, list, path, index);
}

/// Performs the string operation on [yamlEditor] to achieve the effect of
/// appending [elem] to the list.
SourceEdit _addToList(
    YamlEditor yamlEditor, YamlList list, Iterable<Object> path, Object elem) {
  if (list.style == CollectionStyle.FLOW) {
    return _addToFlowList(yamlEditor, list, path, elem);
  } else {
    return _addToBlockList(yamlEditor, list, path, elem);
  }
}

/// Performs the string operation on [yamlEditor] to achieve the effect of
/// prepending [elem] to the list.
SourceEdit _prependToList(
    YamlEditor yamlEditor, YamlList list, Iterable<Object> path, Object elem) {
  if (list.style == CollectionStyle.FLOW) {
    return _prependToFlowList(yamlEditor, list, path, elem);
  } else {
    return _prependToBlockList(yamlEditor, list, path, elem);
  }
}

/// Performs the string operation on [yamlEditor] to achieve a similar effect of
/// inserting [elem] to the list at [index].
SourceEdit _insertInList(YamlEditor yamlEditor, YamlList list,
    Iterable<Object> path, int index, Object elem) {
  if (index > list.length || index < 0) {
    throw RangeError.range(index, 0, list.length);
  }

  /// We call the add method if the user wants to add it to the end of the list
  /// because appending requires different techniques.
  if (index == list.length) {
    return _addToList(yamlEditor, list, path, elem);
  } else {
    if (list.style == CollectionStyle.FLOW) {
      return _insertInFlowList(yamlEditor, list, path, index, elem);
    } else {
      return _insertInBlockList(yamlEditor, list, path, index, elem);
    }
  }
}

/// Gets the indentation level of the list. This is 0 if it is a flow list,
/// but returns the number of spaces before the hyphen of elements for
/// block lists.
int _getListIndentation(YamlEditor yamlEditor, YamlList list) {
  if (list.style == CollectionStyle.FLOW) return 0;

  if (list.nodes.isEmpty) {
    throw UnsupportedError('Unable to get indentation for empty block list');
  }

  final lastSpanOffset = list.nodes.last.span.start.offset;
  var lastNewLine = yamlEditor._yaml.lastIndexOf('\n', lastSpanOffset);
  if (lastNewLine == -1) lastNewLine = 0;
  final lastHyphen = yamlEditor._yaml.lastIndexOf('-', lastSpanOffset);

  return lastHyphen - lastNewLine - 1;
}

/// Returns a new [YamlList] constructed by applying [update] onto the [nodes]
/// of this [YamlList].
YamlList _updatedYamlList(YamlList list, Function(List<YamlNode>) update) {
  final newNodes = [...list.nodes];
  update(newNodes);
  return _yamlNodeFrom(newNodes);
}

/// Performs the string operation on [yamlEditor] to achieve the effect of removing
/// [nodeToRemove] from [nodes], noting that this is a flow list.
SourceEdit _removeFromFlowList(YamlEditor yamlEditor, YamlList list,
    Iterable<Object> path, YamlNode nodeToRemove, int index) {
  final span = nodeToRemove.span;
  var start = span.start.offset;
  var end = span.end.offset;

  if (index == 0) {
    start = yamlEditor._yaml.lastIndexOf('[', start) + 1;
    end = yamlEditor._yaml.indexOf(RegExp(r',|]'), end) + 1;
  } else {
    start = yamlEditor._yaml.lastIndexOf(',', start);
  }

  return SourceEdit(start, end - start, '');
  //final updatedList = _updatedYamlList(list, (nodes) => nodes.removeAt(index));
}

/// Performs the string operation on [yamlEditor] to achieve the effect of removing
/// [nodeToRemove] from [nodes], noting that this is a block list.
SourceEdit _removeFromBlockList(YamlEditor yamlEditor, YamlList list,
    Iterable<Object> path, YamlNode removedNode, int index) {
  final span = removedNode.span;
  final start = yamlEditor._yaml.lastIndexOf('\n', span.start.offset);
  final end = yamlEditor._yaml.indexOf('\n', span.end.offset);

  // updatedList = _updatedYamlList(list, (nodes) => nodes.removeAt(index));
  return SourceEdit(start, end - start, '');
}

/// Returns the index of [element] in the list if present, or -1 if it is absent.
int _indexOf(YamlList list, Object element) {
  for (var i = 0; i < list.length; i++) {
    if (deepEquals(list[i].value, element)) return i;
  }
  return -1;
}

/// Performs the string operation on [yamlEditor] to achieve the effect of prepending
/// [elem] into [nodes], noting that this is a flow list.
SourceEdit _prependToFlowList(
    YamlEditor yamlEditor, YamlList list, Iterable<Object> path, Object elem) {
  var valueString = _getFlowString(elem);
  if (list.nodes.isNotEmpty) valueString = '$valueString, ';

  //final updatedList =
  //  _updatedYamlList(list, (nodes) => nodes.insert(0, _yamlNodeFrom(elem)));
  return SourceEdit(list.span.start.offset + 1, 0, valueString);
}

/// Performs the string operation on [yamlEditor] to achieve the effect of prepending
/// [elem] into [nodes], noting that this is a block list.
SourceEdit _prependToBlockList(
    YamlEditor yamlEditor, YamlList list, Iterable<Object> path, Object elem) {
  final valueString = _getBlockString(
      elem, _getListIndentation(yamlEditor, list) + yamlEditor.indentationStep);
  var formattedValue = ''.padLeft(_getListIndentation(yamlEditor, list)) + '- ';

  if (_isCollection(elem)) {
    formattedValue += valueString.substring(
            _getListIndentation(yamlEditor, list) +
                yamlEditor.indentationStep) +
        '\n';
  } else {
    formattedValue += valueString + '\n';
  }

  final startOffset =
      yamlEditor._yaml.lastIndexOf('\n', list.span.start.offset) + 1;

  // final updatedList =
  //     _updatedYamlList(list, (nodes) => nodes.insert(0, _yamlNodeFrom(elem)));
  return SourceEdit(startOffset, 0, formattedValue);
}

/// Performs the string operation on [yamlEditor] to achieve the effect of insertion
/// [elem] into [nodes] at [index], noting that this is a flow list. [index] should
/// be non-negative and less than or equal to [length].
SourceEdit _insertInFlowList(YamlEditor yamlEditor, YamlList list,
    Iterable<Object> path, int index, Object elem) {
  if (index == list.length) return _addToFlowList(yamlEditor, list, path, elem);
  if (index == 0) return _prependToFlowList(yamlEditor, list, path, elem);

  var valueString = ' ' + _getFlowString(elem);
  if (list.nodes.isNotEmpty) valueString = '$valueString,';

  final currNode = list.nodes[index];
  final currNodeStartIdx = currNode.span.start.offset;
  final startOffset =
      yamlEditor._yaml.lastIndexOf(RegExp(r',|\['), currNodeStartIdx) + 1;

  // final updatedList = _updatedYamlList(
  //     list, (nodes) => nodes.insert(index, _yamlNodeFrom(elem)));
  return SourceEdit(startOffset, 0, valueString);
}

/// Performs the string operation on [yamlEditor] to achieve the effect of insertion
/// [elem] into [nodes] at [index], noting that this is a block list. [index] should
/// be non-negative and less than or equal to [length].
SourceEdit _insertInBlockList(YamlEditor yamlEditor, YamlList list,
    Iterable<Object> path, int index, Object elem) {
  if (index == list.length) {
    return _addToBlockList(yamlEditor, list, path, elem);
  }
  if (index == 0) return _prependToBlockList(yamlEditor, list, path, elem);

  final valueString = _getBlockString(
      elem, _getListIndentation(yamlEditor, list) + yamlEditor.indentationStep);
  var formattedValue = ''.padLeft(_getListIndentation(yamlEditor, list)) + '- ';

  if (_isCollection(elem)) {
    formattedValue += valueString.substring(
            _getListIndentation(yamlEditor, list) +
                yamlEditor.indentationStep) +
        '\n';
  } else {
    formattedValue += valueString + '\n';
  }

  final currNode = list.nodes[index];
  final currNodeStartIdx = currNode.span.start.offset;
  final startOffset = yamlEditor._yaml.lastIndexOf('\n', currNodeStartIdx) + 1;

  //final updatedList = _updatedYamlList(
  //  list, (nodes) => nodes.insert(index, _yamlNodeFrom(elem)));
  return SourceEdit(startOffset, 0, formattedValue);
}

/// Performs the string operation on [yamlEditor] to achieve the effect of addition
/// [elem] into [nodes], noting that this is a flow list.
SourceEdit _addToFlowList(
    YamlEditor yamlEditor, YamlList list, Iterable<Object> path, Object elem) {
  var valueString = _getFlowString(elem);
  if (list.nodes.isNotEmpty) valueString = ', ' + valueString;

  //final updatedList =
  //    _updatedYamlList(list, (nodes) => nodes.add(_yamlNodeFrom(elem)));
  return SourceEdit(list.span.end.offset - 1, 0, valueString);
}

/// Performs the string operation on [yamlEditor] to achieve the effect of addition
/// [elem] into [nodes], noting that this is a
/// block list.
SourceEdit _addToBlockList(
    YamlEditor yamlEditor, YamlList list, Iterable<Object> path, Object elem) {
  final valueString = _getBlockString(
      elem, _getListIndentation(yamlEditor, list) + yamlEditor.indentationStep);
  var formattedValue = ''.padLeft(_getListIndentation(yamlEditor, list)) + '- ';

  if (_isCollection(elem)) {
    formattedValue += valueString.substring(
            _getListIndentation(yamlEditor, list) +
                yamlEditor.indentationStep) +
        '\n';
  } else {
    formattedValue += valueString + '\n';
  }

  // Adjusts offset to after the trailing newline of the last entry, if it exists
  if (list.nodes.isNotEmpty) {
    final lastValueSpanEnd = list.nodes.last.span.end.offset;
    final nextNewLineIndex = yamlEditor._yaml.indexOf('\n', lastValueSpanEnd);
    if (nextNewLineIndex == -1) {
      formattedValue = '\n' + formattedValue;
    }
  }

  //final updatedList =
  //    _updatedYamlList(list, (nodes) => nodes.add(_yamlNodeFrom(elem)));
  return SourceEdit(list.span.end.offset, 0, formattedValue);
}

/// Performs the string operation on [yamlEditor] to achieve the effect of setting
/// the element at [key] to [newValue] when re-parsed.
SourceEdit _setInMap(YamlEditor yamlEditor, YamlMap map, Iterable<Object> path,
    Object key, Object newValue) {
  if (!map.nodes.containsKey(key)) {
    if (map.style == CollectionStyle.FLOW) {
      return _addToFlowMap(yamlEditor, map, path, key, newValue);
    } else {
      return _addToBlockMap(yamlEditor, map, path, key, newValue);
    }
  } else {
    if (map.style == CollectionStyle.FLOW) {
      return _replaceInFlowMap(yamlEditor, map, path, key, newValue);
    } else {
      return _replaceInBlockMap(yamlEditor, map, path, key, newValue);
    }
  }
}

/// Performs the string operation on [yamlEditor] to achieve the effect of removing
/// the element at [key] to [newValue] when re-parsed.
///
/// Returns the [YamlNode] removed.
SourceEdit _removeInMap(
    YamlEditor yamlEditor, YamlMap map, Iterable<Object> path, Object key) {
  if (!map.nodes.containsKey(key)) return null;

  final keyNode = _getKeyNode(map, key);
  final valueNode = map.nodes[key];

  if (map.style == CollectionStyle.FLOW) {
    return _removeFromFlowMap(yamlEditor, map, path, keyNode, valueNode, key);
  } else {
    return _removeFromBlockMap(yamlEditor, map, path, keyNode, valueNode);
  }
}

/// Returns the [YamlNode] corresponding to the provided [key].
YamlNode _getKeyNode(YamlMap map, Object key) {
  return (map.nodes.keys.firstWhere((node) => deepEquals(node, key))
      as YamlNode);
}

/// Gets the indentation level of the map. This is 0 if it is a flow map,
/// but returns the number of spaces before the keys for block maps.
int _getMapIndentation(YamlEditor yamlEditor, YamlMap map) {
  if (map.style == CollectionStyle.FLOW) return 0;

  if (map.nodes.isEmpty) {
    throw UnsupportedError('Unable to get indentation for empty block list');
  }

  final lastKey = map.nodes.keys.last as YamlNode;
  final lastSpanOffset = lastKey.span.start.offset;
  var lastNewLine = yamlEditor._yaml.lastIndexOf('\n', lastSpanOffset);
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

/// Performs the string operation on [yamlEditor] to achieve the effect of adding
/// the [key]:[newValue] pair when reparsed, bearing in mind that this is a flow map.
SourceEdit _addToFlowMap(YamlEditor yamlEditor, YamlMap map,
    Iterable<Object> path, Object key, Object newValue) {
  final valueNode = _yamlNodeFrom(newValue);
  final keyNode = _yamlNodeFrom(key);
  final updatedMap =
      _updatedYamlMap(map, (nodes) => nodes[keyNode] = valueNode);

  // The -1 accounts for the closing bracket.
  if (map.nodes.isEmpty) {
    return SourceEdit(map.span.end.offset - 1, 0, '$key: $newValue');
  } else {
    return SourceEdit(map.span.end.offset - 1, 0, ', $key: $newValue');
  }
}

/// Performs the string operation on [yamlEditor] to achieve the effect of adding
/// the [key]:[newValue] pair when reparsed, bearing in mind that this is a block map.
SourceEdit _addToBlockMap(YamlEditor yamlEditor, YamlMap map,
    Iterable<Object> path, Object key, Object newValue) {
  final valueString = _getBlockString(newValue,
      _getMapIndentation(yamlEditor, map) + yamlEditor.indentationStep);
  var formattedValue = ' ' * _getMapIndentation(yamlEditor, map) + '$key: ';
  var offset = map.span.end.offset;

  // Adjusts offset to after the trailing newline of the last entry, if it exists
  if (map.nodes.isNotEmpty) {
    final lastValueSpanEnd = map.nodes.values.last.span.end.offset;
    final nextNewLineIndex = yamlEditor._yaml.indexOf('\n', lastValueSpanEnd);

    if (nextNewLineIndex != -1) {
      offset = nextNewLineIndex + 1;
    } else {
      formattedValue = '\n' + formattedValue;
    }
  }

  if (_isCollection(newValue)) formattedValue += '\n';

  formattedValue += valueString + '\n';

  final valueNode = _yamlNodeFrom(newValue);
  final keyNode = _yamlNodeFrom(key);
  final updatedMap =
      _updatedYamlMap(map, (nodes) => nodes[keyNode] = valueNode);

  return SourceEdit(offset, 0, formattedValue);
}

/// Performs the string operation on [yamlEditor] to achieve the effect of replacing
/// the value at [key] with [newValue] when reparsed, bearing in mind that this is a
/// flow map.

SourceEdit _replaceInFlowMap(YamlEditor yamlEditor, YamlMap map,
    Iterable<Object> path, Object key, Object newValue) {
  final valueSpan = map.nodes[key].span;
  var valueString = _getFlowString(newValue);

  if (_isCollection(newValue)) valueString = '\n' + valueString;

  final valueNode = _yamlNodeFrom(newValue);
  final keyNode = _getKeyNode(map, key);
  final updatedMap =
      _updatedYamlMap(map, (nodes) => nodes[keyNode] = valueNode);

  return SourceEdit(valueSpan.start.offset,
      valueSpan.end.offset - valueSpan.start.offset, valueString);
}

/// Performs the string operation on [yamlEditor] to achieve the effect of replacing
/// the value at [key] with [newValue] when reparsed, bearing in mind that this is a
/// block map.
SourceEdit _replaceInBlockMap(YamlEditor yamlEditor, YamlMap map,
    Iterable<Object> path, Object key, Object newValue) {
  final value = map.nodes[key];
  final keyNode = _getKeyNode(map, key);
  var valueString = _getBlockString(newValue,
      _getMapIndentation(yamlEditor, map) + yamlEditor.indentationStep);

  /// +2 accounts for the colon
  final start = keyNode.span.end.offset + 2;
  final end = _getContentSensitiveEnd(value);

  if (_isCollection(newValue)) valueString = '\n' + valueString;

  final valueNode = _yamlNodeFrom(newValue);
  final updatedMap =
      _updatedYamlMap(map, (nodes) => nodes[keyNode] = valueNode);

  return SourceEdit(start, end - start, valueString);
}

/// Performs the string operation on [yamlEditor] to achieve the effect of removing
/// the [key] from the map, bearing in mind that this is a flow map.
SourceEdit _removeFromFlowMap(YamlEditor yamlEditor, YamlMap map,
    Iterable<Object> path, YamlNode keyNode, YamlNode valueNode, Object key) {
  final keySpan = keyNode.span;
  final valueSpan = valueNode.span;
  var start = keySpan.start.offset;
  var end = valueSpan.end.offset;

  if (deepEquals(key, map.nodes.keys.first)) {
    start = yamlEditor._yaml.lastIndexOf('{', start) + 1;
    end = yamlEditor._yaml.indexOf(RegExp(r',|}'), end) + 1;
  } else {
    start = yamlEditor._yaml.lastIndexOf(',', start);
  }

  final updatedMap = _updatedYamlMap(map, (nodes) => nodes.remove(keyNode));
  return SourceEdit(start, end - start, '');
}

/// Performs the string operation on [yamlEditor] to achieve the effect of removing
/// the [key] from the map, bearing in mind that this is a block map.
SourceEdit _removeFromBlockMap(YamlEditor yamlEditor, YamlMap map,
    Iterable<Object> path, YamlNode keyNode, YamlNode valueNode) {
  var keySpan = keyNode.span;
  var valueSpan = valueNode.span;
  var start = yamlEditor._yaml.lastIndexOf('\n', keySpan.start.offset);
  var end = yamlEditor._yaml.indexOf('\n', valueSpan.end.offset);

  if (start == -1) start = 0;
  if (end == -1) end = yamlEditor._yaml.length - 1;

  final updatedMap = _updatedYamlMap(map, (nodes) => nodes.remove(keyNode));

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
