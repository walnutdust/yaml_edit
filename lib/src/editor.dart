import 'package:source_span/source_span.dart';
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
  /// Definitely a YamlNode, but dynamic allows us to implement both
  /// Map and List operations easily.
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
      current = current.nodes[key];
    }
    return current;
  }

  /// Sets [value] in the [path].
  ///
  /// If the [path] is not accessible (e.g. it currently does not exist in the document),
  /// an error will be thrown.
  /// TODO: empty path
  void setIn(Iterable<Object> path, Object value) {
    final collectionPath = path.take(path.length - 1);
    final yamlCollection = parseValueAt(collectionPath);
    final lastNode = path.last;

    if (yamlCollection is YamlList) {
      yamlCollection.setIn(this, collectionPath, lastNode, value);
    } else if (yamlCollection is YamlMap) {
      yamlCollection.setIn(this, collectionPath, lastNode, value);
    } else {
      throw TypeError();
    }
  }

  /// Appends [value] into the list at [listPath], only if the element at the given path
  /// is a List.
  void addInList(Iterable<Object> listPath, Object value) {
    final yamlList = _traverseToList(listPath);
    yamlList.addToList(this, listPath, value);
  }

  /// Prepends [value] into the list at [listPath], only if the element at the given path
  /// is a List.
  void prependInList(Iterable<Object> listPath, Object value) {
    final yamlList = _traverseToList(listPath);
    yamlList.prependToList(this, listPath, value);
  }

  /// Inserts [value] into the list at [listPath], only if the element at the given path
  /// is a list. [index] must be non-negative and no greater than the list's length.
  void insertInList(Iterable<Object> listPath, int index, Object value) {
    var yamlList = _traverseToList(listPath);
    yamlList.insertInList(this, listPath, index, value);
  }

  /// Removes the value in the path.
  void removeIn(Iterable<Object> path) {
    final collectionPath = path.take(path.length - 1);
    final current = parseValueAt(collectionPath);
    final lastNode = path.last;

    if (current is YamlList) {
      current.removeInList(this, collectionPath, lastNode);
    } else if (current is YamlMap) {
      current.removeInMap(this, collectionPath, lastNode);
    } else {
      throw TypeError();
    }
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

  /// Utility method to insert [replacement] at [offset] on [_yaml].
  void _insert(int offset, String replacement, Iterable<Object> path,
          YamlNode expectedNode) =>
      _replaceRange(offset, offset, replacement, path, expectedNode);

  /// Utility method to replace the substring in [_yaml] as denoted by
  /// the start and end of [span] with [replacement].
  void _replaceRangeFromSpan(SourceSpan span, String replacement,
      Iterable<Object> path, YamlNode expectedNode) {
    final start = span.start.offset;
    final end = span.end.offset;
    _replaceRange(start, end, replacement, path, expectedNode);
  }

  /// Utility method to remove the substring of [_yaml] within the range
  /// provided by [start] and [end].
  void _removeRange(
          int start, int end, Iterable<Object> path, YamlNode expectedNode) =>
      _replaceRange(start, end, '', path, expectedNode);

  /// Utility method to replace the substring of [_yaml] within the range
  /// provided by [start] and [end] with [replacement].
  ///
  ///
  /// When [_yaml] is modified with this method, the resulting string is parsed
  /// and reloaded and traversed down [path] to ensure that the reparsed node is
  /// equal to [expectedNode] using `package:yaml`'s deep equality.
  void _replaceRange(int start, int end, String replacement,
      Iterable<Object> path, YamlNode expectedNode) {
    _yaml = _yaml.replaceRange(start, end, replacement);
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

    edits.add(SourceEdit(start, end - start, replacement));
  }
}

/// Extension on [YamlList] that creates the string manipulation operations that will
/// result in an equivalent [List] operation when the YAML is reparsed.
extension _ModifiableYamlList on YamlList {
  /// Performs the string operation on [yamlEditor] to achieve the effect of setting
  /// the element at [index] to [newValue] when re-parsed.
  void setIn(YamlEditor yamlEditor, Iterable<Object> path, int index,
      Object newValue) {
    var currValue = nodes[index];
    var valueNode = _yamlNodeFrom(newValue);

    var updatedList = _updatedYamlList((nodes) => nodes[index] = valueNode);

    yamlEditor._replaceRangeFromSpan(
        currValue.span, newValue.toString(), path, updatedList);
  }

  /// Performs the string operation on [yamlEditor] to achieve the effect of removing
  /// the element at [index] when re-parsed.
  ///
  /// Returns the node that is removed.
  YamlNode removeInList(
      YamlEditor yamlEditor, Iterable<Object> path, int index) {
    final nodeToRemove = nodes[index];

    if (style == CollectionStyle.FLOW) {
      _removeFromFlowList(yamlEditor, path, nodeToRemove, index);
    } else {
      _removeFromBlockList(yamlEditor, path, nodeToRemove, index);
    }

    return nodeToRemove;
  }

  /// Performs the string operation on [yamlEditor] to achieve the effect of
  /// removing [elem] when re-parsed.
  ///
  /// Returns `true` if [elem] was successfully found and removed, `false` otherwise.
  bool removeFromList(
      YamlEditor yamlEditor, Iterable<Object> path, Object elem) {
    var index = indexOf(elem);
    if (index == -1) return false;

    removeInList(yamlEditor, path, index);
    return true;
  }

  /// Performs the string operation on [yamlEditor] to achieve the effect of
  /// appending [elem] to the list.
  void addToList(YamlEditor yamlEditor, Iterable<Object> path, Object elem) {
    if (style == CollectionStyle.FLOW) {
      _addToFlowList(yamlEditor, path, elem);
    } else {
      _addToBlockList(yamlEditor, path, elem);
    }
  }

  /// Performs the string operation on [yamlEditor] to achieve the effect of
  /// prepending [elem] to the list.
  void prependToList(
      YamlEditor yamlEditor, Iterable<Object> path, Object elem) {
    if (style == CollectionStyle.FLOW) {
      _prependToFlowList(yamlEditor, path, elem);
    } else {
      _prependToBlockList(yamlEditor, path, elem);
    }
  }

  /// Performs the string operation on [yamlEditor] to achieve a similar effect of
  /// inserting [elem] to the list at [index].
  void insertInList(
      YamlEditor yamlEditor, Iterable<Object> path, int index, Object elem) {
    if (index > length || index < 0) {
      throw RangeError.range(index, 0, length);
    }

    /// We call the add method if the user wants to add it to the end of the list
    /// because appending requires different techniques.
    if (index == length) {
      addToList(yamlEditor, path, elem);
    } else {
      if (style == CollectionStyle.FLOW) {
        _insertInFlowList(yamlEditor, path, index, elem);
      } else {
        _insertInBlockList(yamlEditor, path, index, elem);
      }
    }
  }

  /// Gets the indentation level of the list. This is 0 if it is a flow list,
  /// but returns the number of spaces before the hyphen of elements for
  /// block lists.
  int _getIndentation(YamlEditor yamlEditor) {
    if (style == CollectionStyle.FLOW) return 0;

    if (nodes.isEmpty) {
      throw UnsupportedError('Unable to get indentation for empty block list');
    }

    final lastSpanOffset = nodes.last.span.start.offset;
    var lastNewLine = yamlEditor._yaml.lastIndexOf('\n', lastSpanOffset);
    if (lastNewLine == -1) lastNewLine = 0;
    final lastHyphen = yamlEditor._yaml.lastIndexOf('-', lastSpanOffset);

    return lastHyphen - lastNewLine - 1;
  }

  /// Returns a new [YamlList] constructed by applying [update] onto the [nodes]
  /// of this [YamlList].
  YamlList _updatedYamlList(Function(List<YamlNode>) update) {
    final newNodes = [...nodes];
    update(newNodes);
    return _yamlNodeFrom(newNodes);
  }

  /// Performs the string operation on [yamlEditor] to achieve the effect of removing
  /// [nodeToRemove] from [nodes], noting that this is a flow list.
  void _removeFromFlowList(YamlEditor yamlEditor, Iterable<Object> path,
      YamlNode nodeToRemove, int index) {
    final span = nodeToRemove.span;
    var start = span.start.offset;
    var end = span.end.offset;

    if (index == 0) {
      start = yamlEditor._yaml.lastIndexOf('[', start) + 1;
      end = yamlEditor._yaml.indexOf(RegExp(r',|]'), end) + 1;
    } else {
      start = yamlEditor._yaml.lastIndexOf(',', start);
    }

    final updatedList = _updatedYamlList((nodes) => nodes.removeAt(index));
    yamlEditor._replaceRange(start, end, '', path, updatedList);
  }

  /// Performs the string operation on [yamlEditor] to achieve the effect of removing
  /// [nodeToRemove] from [nodes], noting that this is a block list.
  void _removeFromBlockList(YamlEditor yamlEditor, Iterable<Object> path,
      YamlNode removedNode, int index) {
    final span = removedNode.span;
    final start = yamlEditor._yaml.lastIndexOf('\n', span.start.offset);
    final end = yamlEditor._yaml.indexOf('\n', span.end.offset);

    final updatedList = _updatedYamlList((nodes) => nodes.removeAt(index));
    yamlEditor._replaceRange(start, end, '', path, updatedList);
  }

  /// Returns the index of [element] in the list if present, or -1 if it is absent.
  int indexOf(Object element) {
    for (var i = 0; i < length; i++) {
      if (deepEquals(this[i].value, element)) return i;
    }
    return -1;
  }

  /// Performs the string operation on [yamlEditor] to achieve the effect of prepending
  /// [elem] into [nodes], noting that this is a flow list.
  void _prependToFlowList(
      YamlEditor yamlEditor, Iterable<Object> path, Object elem) {
    var valueString = _getFlowString(elem);
    if (nodes.isNotEmpty) valueString = '$valueString, ';

    final updatedList =
        _updatedYamlList((nodes) => nodes.insert(0, _yamlNodeFrom(elem)));
    yamlEditor._insert(span.start.offset + 1, valueString, path, updatedList);
  }

  /// Performs the string operation on [yamlEditor] to achieve the effect of prepending
  /// [elem] into [nodes], noting that this is a block list.
  void _prependToBlockList(
      YamlEditor yamlEditor, Iterable<Object> path, Object elem) {
    final valueString = _getBlockString(
        elem, _getIndentation(yamlEditor) + yamlEditor.indentationStep);
    var formattedValue = ''.padLeft(_getIndentation(yamlEditor)) + '- ';

    if (_isCollection(elem)) {
      formattedValue += valueString.substring(
              _getIndentation(yamlEditor) + yamlEditor.indentationStep) +
          '\n';
    } else {
      formattedValue += valueString + '\n';
    }

    final startOffset =
        yamlEditor._yaml.lastIndexOf('\n', span.start.offset) + 1;

    final updatedList =
        _updatedYamlList((nodes) => nodes.insert(0, _yamlNodeFrom(elem)));
    yamlEditor._insert(startOffset, formattedValue, path, updatedList);
  }

  /// Performs the string operation on [yamlEditor] to achieve the effect of insertion
  /// [elem] into [nodes] at [index], noting that this is a flow list. [index] should
  /// be non-negative and less than or equal to [length].
  void _insertInFlowList(
      YamlEditor yamlEditor, Iterable<Object> path, int index, Object elem) {
    if (index == length) return _addToFlowList(yamlEditor, path, elem);
    if (index == 0) return _prependToFlowList(yamlEditor, path, elem);

    var valueString = ' ' + _getFlowString(elem);
    if (nodes.isNotEmpty) valueString = '$valueString,';

    final currNode = nodes[index];
    final currNodeStartIdx = currNode.span.start.offset;
    final startOffset =
        yamlEditor._yaml.lastIndexOf(RegExp(r',|\['), currNodeStartIdx) + 1;

    final updatedList =
        _updatedYamlList((nodes) => nodes.insert(index, _yamlNodeFrom(elem)));
    yamlEditor._insert(startOffset, valueString, path, updatedList);
  }

  /// Performs the string operation on [yamlEditor] to achieve the effect of insertion
  /// [elem] into [nodes] at [index], noting that this is a block list. [index] should
  /// be non-negative and less than or equal to [length].
  void _insertInBlockList(
      YamlEditor yamlEditor, Iterable<Object> path, int index, Object elem) {
    if (index == length) return _addToBlockList(yamlEditor, path, elem);
    if (index == 0) return _prependToBlockList(yamlEditor, path, elem);

    final valueString = _getBlockString(
        elem, _getIndentation(yamlEditor) + yamlEditor.indentationStep);
    var formattedValue = ''.padLeft(_getIndentation(yamlEditor)) + '- ';

    if (_isCollection(elem)) {
      formattedValue += valueString.substring(
              _getIndentation(yamlEditor) + yamlEditor.indentationStep) +
          '\n';
    } else {
      formattedValue += valueString + '\n';
    }

    final currNode = nodes[index];
    final currNodeStartIdx = currNode.span.start.offset;
    final startOffset =
        yamlEditor._yaml.lastIndexOf('\n', currNodeStartIdx) + 1;

    final updatedList =
        _updatedYamlList((nodes) => nodes.insert(index, _yamlNodeFrom(elem)));
    yamlEditor._insert(startOffset, formattedValue, path, updatedList);
  }

  /// Performs the string operation on [yamlEditor] to achieve the effect of addition
  /// [elem] into [nodes], noting that this is a flow list.
  void _addToFlowList(
      YamlEditor yamlEditor, Iterable<Object> path, Object elem) {
    var valueString = _getFlowString(elem);
    if (nodes.isNotEmpty) valueString = ', ' + valueString;

    final updatedList =
        _updatedYamlList((nodes) => nodes.add(_yamlNodeFrom(elem)));
    yamlEditor._insert(span.end.offset - 1, valueString, path, updatedList);
  }

  /// Performs the string operation on [yamlEditor] to achieve the effect of addition
  /// [elem] into [nodes], noting that this is a block list.
  void _addToBlockList(
      YamlEditor yamlEditor, Iterable<Object> path, Object elem) {
    final valueString = _getBlockString(
        elem, _getIndentation(yamlEditor) + yamlEditor.indentationStep);
    var formattedValue = ''.padLeft(_getIndentation(yamlEditor)) + '- ';

    if (_isCollection(elem)) {
      formattedValue += valueString.substring(
              _getIndentation(yamlEditor) + yamlEditor.indentationStep) +
          '\n';
    } else {
      formattedValue += valueString + '\n';
    }

    // Adjusts offset to after the trailing newline of the last entry, if it exists
    if (nodes.isNotEmpty) {
      final lastValueSpanEnd = nodes.last.span.end.offset;
      final nextNewLineIndex = yamlEditor._yaml.indexOf('\n', lastValueSpanEnd);
      if (nextNewLineIndex == -1) {
        formattedValue = '\n' + formattedValue;
      }
    }

    final updatedList =
        _updatedYamlList((nodes) => nodes.add(_yamlNodeFrom(elem)));
    yamlEditor._insert(span.end.offset, formattedValue, path, updatedList);
  }
}

/// Extension on [YamlMap] that creates the string manipulation operations that will
/// result in an equivalent [Map] operation when the YAML is reparsed.
extension _ModifiableYamlMap on YamlMap {
  /// Performs the string operation on [yamlEditor] to achieve the effect of setting
  /// the element at [key] to [newValue] when re-parsed.
  void setIn(YamlEditor yamlEditor, Iterable<Object> path, Object key,
      Object newValue) {
    if (!nodes.containsKey(key)) {
      if (style == CollectionStyle.FLOW) {
        _addToFlowMap(yamlEditor, path, key, newValue);
      } else {
        _addToBlockMap(yamlEditor, path, key, newValue);
      }
    } else {
      if (style == CollectionStyle.FLOW) {
        _replaceInFlowMap(yamlEditor, path, key, newValue);
      } else {
        _replaceInBlockMap(yamlEditor, path, key, newValue);
      }
    }
  }

  /// Performs the string operation on [yamlEditor] to achieve the effect of removing
  /// the element at [key] to [newValue] when re-parsed.
  ///
  /// Returns the [YamlNode] removed.
  YamlNode removeInMap(
      YamlEditor yamlEditor, Iterable<Object> path, Object key) {
    if (!nodes.containsKey(key)) return null;

    final keyNode = _getKeyNode(key);
    final valueNode = nodes[key];

    if (style == CollectionStyle.FLOW) {
      _removeFromFlowMap(yamlEditor, path, keyNode, valueNode, key);
    } else {
      _removeFromBlockMap(yamlEditor, path, keyNode, valueNode);
    }

    return valueNode;
  }

  /// Returns the [YamlNode] corresponding to the provided [key].
  YamlNode _getKeyNode(Object key) {
    return (nodes.keys.firstWhere((node) => deepEquals(node, key)) as YamlNode);
  }

  /// Gets the indentation level of the map. This is 0 if it is a flow map,
  /// but returns the number of spaces before the keys for block maps.
  int _getIndentation(yamlEditor) {
    if (style == CollectionStyle.FLOW) return 0;

    if (nodes.isEmpty) {
      throw UnsupportedError('Unable to get indentation for empty block list');
    }

    final lastKey = nodes.keys.last as YamlNode;
    final lastSpanOffset = lastKey.span.start.offset;
    var lastNewLine = yamlEditor._yaml.lastIndexOf('\n', lastSpanOffset);
    if (lastNewLine == -1) lastNewLine = 0;

    return lastSpanOffset - lastNewLine - 1;
  }

  /// Returns a new [YamlMap] constructed by applying [update] onto the [nodes]
  /// of this [YamlMap].
  YamlMap _updatedYamlMap(Function(Map<dynamic, YamlNode>) update) {
    final dummyMap = {...nodes};
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
  void _addToFlowMap(YamlEditor yamlEditor, Iterable<Object> path, Object key,
      Object newValue) {
    final valueNode = _yamlNodeFrom(newValue);
    final keyNode = _yamlNodeFrom(key);
    final updatedMap = _updatedYamlMap((nodes) => nodes[keyNode] = valueNode);

    // The -1 accounts for the closing bracket.
    if (nodes.isEmpty) {
      yamlEditor._insert(
          span.end.offset - 1, '$key: $newValue', path, updatedMap);
    } else {
      yamlEditor._insert(
          span.end.offset - 1, ', $key: $newValue', path, updatedMap);
    }
  }

  /// Performs the string operation on [yamlEditor] to achieve the effect of adding
  /// the [key]:[newValue] pair when reparsed, bearing in mind that this is a block map.
  void _addToBlockMap(YamlEditor yamlEditor, Iterable<Object> path, Object key,
      Object newValue) {
    final valueString = _getBlockString(
        newValue, _getIndentation(yamlEditor) + yamlEditor.indentationStep);
    var formattedValue = ' ' * _getIndentation(yamlEditor) + '$key: ';
    var offset = span.end.offset;

    // Adjusts offset to after the trailing newline of the last entry, if it exists
    if (nodes.isNotEmpty) {
      final lastValueSpanEnd = nodes.values.last.span.end.offset;
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
    final updatedMap = _updatedYamlMap((nodes) => nodes[keyNode] = valueNode);

    yamlEditor._insert(offset, formattedValue, path, updatedMap);
  }

  /// Performs the string operation on [yamlEditor] to achieve the effect of replacing
  /// the value at [key] with [newValue] when reparsed, bearing in mind that this is a
  /// flow map.
  void _replaceInFlowMap(YamlEditor yamlEditor, Iterable<Object> path,
      Object key, Object newValue) {
    final valueSpan = nodes[key].span;
    var valueString = _getFlowString(newValue);

    if (_isCollection(newValue)) valueString = '\n' + valueString;

    final valueNode = _yamlNodeFrom(newValue);
    final keyNode = _getKeyNode(key);
    final updatedMap = _updatedYamlMap((nodes) => nodes[keyNode] = valueNode);

    yamlEditor._replaceRangeFromSpan(valueSpan, valueString, path, updatedMap);
  }

  /// Performs the string operation on [yamlEditor] to achieve the effect of replacing
  /// the value at [key] with [newValue] when reparsed, bearing in mind that this is a
  /// block map.
  void _replaceInBlockMap(YamlEditor yamlEditor, Iterable<Object> path,
      Object key, Object newValue) {
    final value = nodes[key];
    final keyNode = _getKeyNode(key);
    var valueString = _getBlockString(
        newValue, _getIndentation(yamlEditor) + yamlEditor.indentationStep);

    /// +2 accounts for the colon
    final start = keyNode.span.end.offset + 2;
    final end = _getContentSensitiveEnd(value);

    if (_isCollection(newValue)) valueString = '\n' + valueString;

    final valueNode = _yamlNodeFrom(newValue);
    final updatedMap = _updatedYamlMap((nodes) => nodes[keyNode] = valueNode);

    yamlEditor._replaceRange(start, end, valueString, path, updatedMap);
  }

  /// Performs the string operation on [yamlEditor] to achieve the effect of removing
  /// the [key] from the map, bearing in mind that this is a flow map.
  void _removeFromFlowMap(YamlEditor yamlEditor, Iterable<Object> path,
      YamlNode keyNode, YamlNode valueNode, Object key) {
    final keySpan = keyNode.span;
    final valueSpan = valueNode.span;
    var start = keySpan.start.offset;
    var end = valueSpan.end.offset;

    if (deepEquals(key, nodes.keys.first)) {
      start = yamlEditor._yaml.lastIndexOf('{', start) + 1;
      end = yamlEditor._yaml.indexOf(RegExp(r',|}'), end) + 1;
    } else {
      start = yamlEditor._yaml.lastIndexOf(',', start);
    }

    final updatedMap = _updatedYamlMap((nodes) => nodes.remove(keyNode));
    yamlEditor._removeRange(start, end, path, updatedMap);
  }

  /// Performs the string operation on [yamlEditor] to achieve the effect of removing
  /// the [key] from the map, bearing in mind that this is a block map.
  void _removeFromBlockMap(YamlEditor yamlEditor, Iterable<Object> path,
      YamlNode keyNode, YamlNode valueNode) {
    var keySpan = keyNode.span;
    var valueSpan = valueNode.span;
    var start = yamlEditor._yaml.lastIndexOf('\n', keySpan.start.offset);
    var end = yamlEditor._yaml.indexOf('\n', valueSpan.end.offset);

    if (start == -1) start = 0;
    if (end == -1) end = yamlEditor._yaml.length - 1;

    final updatedMap = _updatedYamlMap((nodes) => nodes.remove(keyNode));

    yamlEditor._removeRange(start, end, path, updatedMap);
  }
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
