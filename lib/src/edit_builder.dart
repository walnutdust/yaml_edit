import 'dart:collection' as collection;

import 'package:source_span/source_span.dart';
import 'package:yaml/src/equality.dart';
import 'package:yaml/src/yaml_node_wrapper.dart';
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
class YamlEditBuilder {
  final List<SourceEdit> _edits = [];
  List<SourceEdit> get edits => [..._edits];

  /// Current YAML string.
  String _yaml;

  /// Root node of YAML AST.
  /// Definitely a _ModifiableYamlNode, but dynamic allows us to implement both
  /// Map and List operations easily.
  dynamic _contents;

  final int indentationStep;

  @override
  String toString() => _yaml;

  YamlEditBuilder(this._yaml, {this.indentationStep = 2}) {
    var contents = loadYamlNode(_yaml);
    _contents = _modifiedYamlNodeFrom(contents, this, []);
  }

  /// Traverses down the provided [path] to the _ModifiableYamlNode at [path].
  _ModifiableYamlNode _traverse(Iterable<Object> path) {
    var current = _contents;
    for (var key in path) {
      current = current[key];
    }
    return current;
  }

  /// Traverses down the provided [path] to the _ModifiableYamlList at [path].
  _ModifiableYamlList _traverseToList(Iterable<Object> path) {
    var possibleList = _traverse(path);

    if (possibleList is _ModifiableYamlList) {
      return possibleList;
    } else {
      throw TypeError();
    }
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
  YamlNode parseValueAt(Iterable<Object> path) {
    var value = _traverse(path).value;

    if (value is _ModifiableYamlList) {
      return YamlList.wrap(value);
    } else if (value is _ModifiableYamlMap) {
      return YamlMap.wrap(value);
    } else {
      return YamlScalar.wrap(value);
    }
  }

  /// Sets [value] in the [path]. If the [path] is not accessible (e.g. it currently
  /// does not exist in the document), an error will be thrown.
  void setIn(Iterable<Object> path, Object value) {
    var yamlCollection = _traverse(path.take(path.length - 1));

    if (yamlCollection is _ModifiableYamlList) {
      var lastNode = path.last;
      yamlCollection[lastNode] = value;
    } else if (yamlCollection is _ModifiableYamlMap) {
      var lastNode = path.last;
      yamlCollection[lastNode] = value;
    } else {
      throw TypeError();
    }
  }

  /// Appends [value] into the list at [listPath], only if the element at the given path
  /// is a List.
  void addInList(Iterable<Object> listPath, Object value) {
    var yamlList = _traverseToList(listPath);
    yamlList.add(value);
  }

  /// Prepends [value] into the list at [listPath], only if the element at the given path
  /// is a List.
  void prependInList(Iterable<Object> listPath, Object value) {
    var yamlList = _traverseToList(listPath);
    yamlList.prepend(value);
  }

  /// Inserts [value] into the list at [listPath], only if the element at the given path
  /// is a list. [index] must be non-negative and no greater than the list's length.
  void insertInList(Iterable<Object> listPath, int index, Object value) {
    var yamlList = _traverseToList(listPath);
    yamlList.insert(index, value);
  }

  /// Removes the value in the path.
  void removeIn(Iterable<Object> path) {
    var current = _traverse(path.take(path.length - 1));
    var lastNode = path.last;

    if (current is _ModifiableYamlList) {
      current.removeAt(lastNode);
    } else if (current is _ModifiableYamlMap) {
      current.remove(lastNode);
    } else {
      throw TypeError();
    }
  }

  /// Utility method to insert [replacement] at [offset] on [_yaml].
  void _insert(int offset, String replacement, Iterable<Object> path,
          _ModifiableYamlNode expectedNode) =>
      _replaceRange(offset, offset, replacement, path, expectedNode);

  /// Utility method to replace the substring in [_yaml] as denoted by
  /// the start and end of [span] with [replacement].
  void _replaceRangeFromSpan(SourceSpan span, String replacement,
      Iterable<Object> path, _ModifiableYamlNode expectedNode) {
    var start = span.start.offset;
    var end = span.end.offset;
    _replaceRange(start, end, replacement, path, expectedNode);
  }

  /// Utility method to remove the substring of [_yaml] within the range
  /// provided by [start] and [end].
  void _removeRange(int start, int end, Iterable<Object> path,
          _ModifiableYamlNode expectedNode) =>
      _replaceRange(start, end, '', path, expectedNode);

  /// Utility method to replace the substring of [_yaml] within the range
  /// provided by [start] and [end] with [replacement], and then reloading
  /// the data structure represented by [_yaml].
  void _replaceRange(int start, int end, String replacement,
      Iterable<Object> path, _ModifiableYamlNode expectedNode) {
    _yaml = _yaml.replaceRange(start, end, replacement);
    var contents = loadYamlNode(_yaml);
    _contents = _modifiedYamlNodeFrom(contents, this, []);

    var actualNode = _traverse(path);

    if (!deepEquals(actualNode, expectedNode)) {
      throw Exception(
          'Modification did not result in expected result! Obtained: \n$actualNode\nExpected: \n$expectedNode');
    }

    _edits.add(SourceEdit(start, end - start, replacement));
  }
}

/// An interface for modifiable YAML nodes from a YAML AST.
/// On top of the [YamlNode] elements, [_ModifiableYamlNode] also
/// has the base [YamlEditBuilder] object so that we can imitate modifications.
abstract class _ModifiableYamlNode extends YamlNode {
  final SourceSpan _span;

  @override
  SourceSpan get span => _span;

  final YamlEditBuilder _baseYaml;

  _ModifiableYamlNode(this._span, this._baseYaml);
}

/// A wrapped scalar parsed from YAML.
class _ModifiableYamlScalar extends _ModifiableYamlNode {
  /// The [YamlScalar] from which this instance was created.
  final YamlScalar _yamlScalar;

  @override
  dynamic get value => _yamlScalar.value;

  _ModifiableYamlScalar.from(this._yamlScalar, YamlEditBuilder baseYaml)
      : super(_yamlScalar.span, baseYaml);

  @override
  String toString() {
    return _yamlScalar.value.toString();
  }

  @override
  bool operator ==(dynamic other) {
    if (other is _ModifiableYamlScalar) {
      return value == other.value;
    }

    return value == other;
  }
}

/// A wrapped list parsed from YAML, extended with methods to allow modification
/// on the base YAML document.
class _ModifiableYamlList extends _ModifiableYamlNode
    with collection.ListMixin {
  final YamlList _yamlList;

  final List<_ModifiableYamlNode> nodes = [];

  final CollectionStyle style;

  final List<Object> _path;

  @override
  int get length => nodes.length;

  @override
  set length(int index) =>
      throw UnsupportedError("This method shouldn't be called!");

  @override
  List get value => this;

  @override
  bool operator ==(dynamic other) {
    if (other is List) {
      if (length != other.length) return false;

      for (var i = 0; i < length; i++) {
        if (this[i] != other[i]) return false;
      }

      return true;
    }

    return false;
  }

  /// Initializes a [_ModifiableYamlList] from a [YamlList].
  ///
  /// [baseYaml] is the base [YamlEditBuilder] that [yamlList] is taken from.
  _ModifiableYamlList.from(this._yamlList, YamlEditBuilder baseYaml, this._path)
      : style = _yamlList.style,
        super(_yamlList.span, baseYaml) {
    for (var node in _yamlList.nodes) {
      nodes.add(_modifiedYamlNodeFrom(node, _baseYaml, [..._path, length]));
    }
  }

  /// Clones this _ModifiableYamlList
  _ModifiableYamlList _clone() {
    return _ModifiableYamlList.from(_yamlList, _baseYaml, _path);
  }

  /// Gets the indentation level of the list. This is 0 if it is a flow list,
  /// but returns the number of spaces before the hyphen of elements for
  /// block lists.
  int get indentation {
    if (style == CollectionStyle.FLOW) return 0;

    if (nodes.isEmpty) {
      throw UnsupportedError('Unable to get indentation for empty block list');
    }

    var lastSpanOffset = nodes.last.span.start.offset;
    var lastNewLine = _baseYaml._yaml.lastIndexOf('\n', lastSpanOffset);
    if (lastNewLine == -1) lastNewLine = 0;
    var lastHyphen = _baseYaml._yaml.lastIndexOf('-', lastSpanOffset);

    return lastHyphen - lastNewLine - 1;
  }

  @override
  _ModifiableYamlNode operator [](int index) => nodes[index];

  @override
  void operator []=(int index, Object newValue) {
    var currValue = nodes[index];
    var updatedList = _clone();
    updatedList.nodes[index] =
        _dummyMYamlNodeFrom(newValue, _baseYaml, [..._path, index]);

    _baseYaml._replaceRangeFromSpan(
        currValue._span, newValue.toString(), _path, updatedList);
  }

  @override
  _ModifiableYamlNode removeAt(int index) {
    var nodeToRemove = nodes[index];

    if (style == CollectionStyle.FLOW) {
      _removeFromFlowList(nodeToRemove, index);
    } else {
      _removeFromBlockList(nodeToRemove, index);
    }

    return nodeToRemove;
  }

  @override
  bool remove(Object elem) {
    var index = indexOf(elem);
    if (index == -1) return false;

    removeAt(index);
    return true;
  }

  /// Adds [elem] to the end of the list.
  @override
  void add(Object elem) {
    if (style == CollectionStyle.FLOW) {
      _addToFlowList(elem);
    } else {
      _addToBlockList(elem);
    }
  }

  /// Adds [elem] to the start of the list.
  void prepend(Object elem) {
    if (style == CollectionStyle.FLOW) {
      _prependToFlowList(elem);
    } else {
      _prependToBlockList(elem);
    }
  }

  /// Adds [elem] to the list at [index]. [index] should be non-negative and
  /// no more than [length].
  @override
  void insert(int index, Object elem) {
    if (index > length || index < 0) {
      throw RangeError.range(index, 0, length);
    }

    /// We call the add method if the user wants to add it to the end of the list
    /// because appending requires different techniques.
    if (index == length) {
      add(elem);
    } else {
      if (style == CollectionStyle.FLOW) {
        _insertInFlowList(index, elem);
      } else {
        _insertInBlockList(index, elem);
      }
    }
  }

  /// Performs the removal of [removedNode] from the base yaml, noting that
  /// the current list is a flow list.
  void _removeFromFlowList(_ModifiableYamlNode nodeToRemove, int index) {
    var span = nodeToRemove._span;
    var start = span.start.offset;
    var end = span.end.offset;

    if (index == 0) {
      start = _baseYaml._yaml.lastIndexOf('[', start) + 1;
      end = _baseYaml._yaml.indexOf(RegExp(r',|]'), end) + 1;
    } else {
      start = _baseYaml._yaml.lastIndexOf(',', start);
    }

    var updatedList = _clone();
    updatedList.nodes.removeAt(index);

    _baseYaml._replaceRange(start, end, '', _path, updatedList);
  }

  /// Performs the removal of [removedNode] from the base yaml, noting that
  /// the current list is a block list.
  void _removeFromBlockList(_ModifiableYamlNode removedNode, int index) {
    var span = removedNode._span;
    var start = _baseYaml._yaml.lastIndexOf('\n', span.start.offset);
    var end = _baseYaml._yaml.indexOf('\n', span.end.offset);
    var updatedList = _clone();
    updatedList.nodes.removeAt(index);

    _baseYaml._replaceRange(start, end, '', _path, updatedList);
  }

  /// Overriding indexOf to provide deep equality, allowing users to remove
  /// elements by the values rather than requiring them to construct
  /// [_ModifiableYamlNode]s
  @override
  int indexOf(Object element, [int start = 0]) {
    if (start < 0) start = 0;
    for (var i = start; i < length; i++) {
      if (deepEquals(this[i].value, element)) return i;
    }
    return -1;
  }

  /// Performs the prepending of [elem] into the base yaml, noting that the current
  /// list is a flow list.
  void _prependToFlowList(Object elem) {
    var valueString = _getFlowString(elem);
    if (nodes.isNotEmpty) valueString = '$valueString, ';

    var updatedList = _clone();
    updatedList.nodes.insert(
        0, _dummyMYamlNodeFrom(elem, _baseYaml, [..._path, nodes.length]));

    _baseYaml._insert(span.start.offset + 1, valueString, _path, updatedList);
  }

  /// Performs the prepending of [elem] into the base yaml, noting that the current
  /// list is a block list.
  void _prependToBlockList(Object elem) {
    var valueString =
        _getBlockString(elem, indentation + _baseYaml.indentationStep);
    var formattedValue = ''.padLeft(indentation) + '- ';

    if (_isCollection(elem)) {
      formattedValue +=
          valueString.substring(indentation + _baseYaml.indentationStep) + '\n';
    } else {
      formattedValue += valueString + '\n';
    }

    var startOffset = _baseYaml._yaml.lastIndexOf('\n', span.start.offset) + 1;

    var updatedList = _clone();
    updatedList.nodes.insert(
        0, _dummyMYamlNodeFrom(elem, _baseYaml, [..._path, nodes.length]));

    _baseYaml._insert(startOffset, formattedValue, _path, updatedList);
  }

  /// Performs the prepending of [elem] into the base yaml, noting that the current
  /// list is a flow list. [index] should be non-negative and less than or equal
  /// to [length].
  void _insertInFlowList(int index, Object elem) {
    if (index < 0 || index > length) {
      throw RangeError.range(index, 0, length);
    }
    if (index == length) return _addToFlowList(elem);
    if (index == 0) return _prependToFlowList(elem);

    var valueString = ' ' + _getFlowString(elem);
    if (nodes.isNotEmpty) valueString = '$valueString,';

    var currNode = nodes[index];
    var currNodeStartIdx = currNode.span.start.offset;
    var startOffset =
        _baseYaml._yaml.lastIndexOf(RegExp(r',|\['), currNodeStartIdx) + 1;

    var updatedList = _clone();
    updatedList.nodes.insert(
        index, _dummyMYamlNodeFrom(elem, _baseYaml, [..._path, nodes.length]));

    _baseYaml._insert(startOffset, valueString, _path, updatedList);
  }

  /// Performs the prepending of [elem] into the base yaml, noting that the current
  /// list is a block list. [index] should be non-negative and less than or equal
  /// to [length].
  void _insertInBlockList(int index, Object elem) {
    if (index < 0 || index > length) {
      throw RangeError.range(index, 0, length);
    }
    if (index == length) return _addToBlockList(elem);
    if (index == 0) return _prependToBlockList(elem);

    var valueString =
        _getBlockString(elem, indentation + _baseYaml.indentationStep);
    var formattedValue = ''.padLeft(indentation) + '- ';

    if (_isCollection(elem)) {
      formattedValue +=
          valueString.substring(indentation + _baseYaml.indentationStep) + '\n';
    } else {
      formattedValue += valueString + '\n';
    }

    var currNode = nodes[index];
    var currNodeStartIdx = currNode.span.start.offset;
    var startOffset = _baseYaml._yaml.lastIndexOf('\n', currNodeStartIdx) + 1;

    var updatedList = _clone();
    updatedList.nodes.insert(
        index, _dummyMYamlNodeFrom(elem, _baseYaml, [..._path, nodes.length]));

    _baseYaml._insert(startOffset, formattedValue, _path, updatedList);
  }

  /// Performs the addition of [elem] into the base yaml, noting that the current
  /// list is a flow list.
  void _addToFlowList(Object elem) {
    var valueString = _getFlowString(elem);
    if (nodes.isNotEmpty) valueString = ', ' + valueString;

    var updatedList = _clone();
    updatedList.nodes
        .add(_dummyMYamlNodeFrom(elem, _baseYaml, [..._path, nodes.length]));

    _baseYaml._insert(span.end.offset - 1, valueString, _path, updatedList);
  }

  /// Performs the addition of [elem] into the base yaml, noting that the current
  /// list is a block list.
  void _addToBlockList(Object elem) {
    var valueString =
        _getBlockString(elem, indentation + _baseYaml.indentationStep);
    var formattedValue = ''.padLeft(indentation) + '- ';

    if (_isCollection(elem)) {
      formattedValue +=
          valueString.substring(indentation + _baseYaml.indentationStep) + '\n';
    } else {
      formattedValue += valueString + '\n';
    }

    // Adjusts offset to after the trailing newline of the last entry, if it exists
    if (nodes.isNotEmpty) {
      var lastValueSpanEnd = nodes.last._span.end.offset;
      var nextNewLineIndex = _baseYaml._yaml.indexOf('\n', lastValueSpanEnd);
      if (nextNewLineIndex == -1) {
        formattedValue = '\n' + formattedValue;
      }
    }

    var updatedList = _clone();
    updatedList.nodes
        .add(_dummyMYamlNodeFrom(elem, _baseYaml, [..._path, nodes.length]));

    _baseYaml._insert(span.end.offset, formattedValue, _path, updatedList);
  }
}

/// A wrapped map parsed from YAML, extended with methods to allow modification
/// on the base YAML document.
class _ModifiableYamlMap extends _ModifiableYamlNode with collection.MapMixin {
  final YamlMap _yamlMap;

  @override
  int get length => nodes.length;

  final CollectionStyle style;

  final Map<dynamic, _ModifiableYamlNode> nodes =
      deepEqualsMap<dynamic, _ModifiableYamlNode>();

  final List<Object> _path;

  @override
  String toString() => nodes.toString();

  @override
  bool operator ==(dynamic other) {
    if (other is Map) {
      if (length != other.length) return false;

      var keyList = keys.toList();
      for (var i = 0; i < length; i++) {
        var key = keyList[i];
        var keyNode = getKeyNode(key);

        if (!other.containsKey(key) || this[keyNode] != other[key]) {
          return false;
        }
      }

      return true;
    }

    return false;
  }

  /// Gets the indentation level of the map. This is 0 if it is a flow map,
  /// but returns the number of spaces before the keys for block maps.
  int get indentation {
    if (style == CollectionStyle.FLOW) return 0;

    if (nodes.isEmpty) {
      throw UnsupportedError('Unable to get indentation for empty block list');
    }

    var lastKey = nodes.keys.last as YamlNode;
    var lastSpanOffset = lastKey.span.start.offset;
    var lastNewLine = _baseYaml._yaml.lastIndexOf('\n', lastSpanOffset);
    if (lastNewLine == -1) lastNewLine = 0;

    return lastSpanOffset - lastNewLine - 1;
  }

  _ModifiableYamlMap.from(this._yamlMap, YamlEditBuilder baseYaml, this._path)
      : style = _yamlMap.style,
        super(_yamlMap.span, baseYaml) {
    for (var entry in _yamlMap.nodes.entries) {
      nodes[entry.key] =
          _modifiedYamlNodeFrom(entry.value, baseYaml, [..._path, entry.key]);
    }
  }

  /// Clones this [_ModifiableYamlMap].
  _ModifiableYamlMap _clone() {
    return _ModifiableYamlMap.from(_yamlMap, _baseYaml, _path);
  }

  @override
  _ModifiableYamlNode operator [](Object key) => nodes[key];

  @override
  void operator []=(Object key, Object newValue) {
    if (!nodes.containsKey(key)) {
      if (style == CollectionStyle.FLOW) {
        _addToFlowMap(key, newValue);
      } else {
        _addToBlockMap(key, newValue);
      }
    } else {
      if (style == CollectionStyle.FLOW) {
        _replaceInFlowMap(key, newValue);
      } else {
        _replaceInBlockMap(key, newValue);
      }
    }
  }

  /// Returns the [YamlNode] given by the provided [key]
  YamlNode getKeyNode(Object key) {
    return (nodes.keys.firstWhere((node) => node.value == key) as YamlNode);
  }

  @override
  _ModifiableYamlNode remove(Object key) {
    if (!nodes.containsKey(key)) return null;

    var keyNode = getKeyNode(key);
    var valueNode = nodes[key];

    if (style == CollectionStyle.FLOW) {
      _removeFromFlowMap(keyNode, valueNode, key);
    } else {
      _removeFromBlockMap(keyNode, valueNode);
    }

    return valueNode;
  }

  @override
  Map get value => this;

  /// Adds the [key]:[newValue] pairing into the map, bearing in mind
  /// that it is a flow Map.
  void _addToFlowMap(Object key, Object newValue) {
    var valueNode = _dummyMYamlNodeFrom(newValue, _baseYaml, [..._path, key]);

    var updatedMap = _clone();
    updatedMap.nodes[key] = valueNode;
    // The -1 accounts for the closing bracket.
    if (nodes.isEmpty) {
      _baseYaml._insert(
          span.end.offset - 1, '$key: $newValue', _path, updatedMap);
    } else {
      _baseYaml._insert(
          span.end.offset - 1, ', $key: $newValue', _path, updatedMap);
    }
  }

  /// Adds the [key]:[newValue] pairing into the map, bearing in mind
  /// that it is a block Map.
  void _addToBlockMap(Object key, Object newValue) {
    var valueString =
        _getBlockString(newValue, indentation + _baseYaml.indentationStep);
    var formattedValue = ' ' * indentation + '$key: ';
    var offset = span.end.offset;

    // Adjusts offset to after the trailing newline of the last entry, if it exists
    if (nodes.isNotEmpty) {
      var lastValueSpanEnd = nodes.values.last._span.end.offset;
      var nextNewLineIndex = _baseYaml._yaml.indexOf('\n', lastValueSpanEnd);

      if (nextNewLineIndex != -1) {
        offset = nextNewLineIndex + 1;
      } else {
        formattedValue = '\n' + formattedValue;
      }
    }

    if (_isCollection(newValue)) formattedValue += '\n';

    formattedValue += valueString + '\n';
    var updatedMap = _clone();

    var valueNode = _dummyMYamlNodeFrom(newValue, _baseYaml, [..._path, key]);
    updatedMap.nodes[key] = valueNode;

    _baseYaml._insert(offset, formattedValue, _path, updatedMap);
  }

  /// Updates the [key]:[newValue] pairing into the map, bearing in mind
  /// that it is a flow Map.
  void _replaceInFlowMap(Object key, Object newValue) {
    var valueSpan = nodes[key].span;
    var valueString = _getFlowString(newValue);

    if (_isCollection(newValue)) valueString = '\n' + valueString;

    var updatedMap = _clone();
    var valueNode = _dummyMYamlNodeFrom(newValue, _baseYaml, [..._path, key]);
    updatedMap.nodes[key] = valueNode;

    _baseYaml._replaceRangeFromSpan(valueSpan, valueString, _path, updatedMap);
  }

  /// Updates the [key]:[newValue] pairing into the map, bearing in mind
  /// that it is a block Map.
  void _replaceInBlockMap(Object key, Object newValue) {
    var value = nodes[key];
    var valueString =
        _getBlockString(newValue, indentation + _baseYaml.indentationStep);
    var start = getKeyNode(key).span.end.offset + 2;
    var end = _getContentSensitiveEnd(value);

    if (_isCollection(newValue)) valueString = '\n' + valueString;

    var updatedMap = _clone();
    var valueNode = _dummyMYamlNodeFrom(newValue, _baseYaml, [..._path, key]);
    updatedMap.nodes[key] = valueNode;

    _baseYaml._replaceRange(start, end, valueString, _path, updatedMap);
  }

  @override
  void clear() {
    var updatedMap = _clone();
    updatedMap.nodes.clear();
    _baseYaml._replaceRangeFromSpan(span, '', _path, updatedMap);
  }

  @override
  Iterable get keys => nodes.keys.map((node) {
        if (node is YamlNode) return node.value;
        return node;
      });

  /// Removes the [key]:[newValue] pairing from the map, bearing in mind
  /// that it is a flow Map.
  void _removeFromFlowMap(
      YamlNode keyNode, _ModifiableYamlNode valueNode, Object key) {
    var keySpan = keyNode.span;
    var valueSpan = valueNode.span;
    var start = keySpan.start.offset;
    var end = valueSpan.end.offset;

    if (deepEquals(key, nodes.keys.first)) {
      start = _baseYaml._yaml.lastIndexOf('{', start) + 1;
      end = _baseYaml._yaml.indexOf(RegExp(r',|}'), end) + 1;
    } else {
      start = _baseYaml._yaml.lastIndexOf(',', start);
    }

    var updatedMap = _clone();
    updatedMap.nodes.remove(keyNode);
    _baseYaml._removeRange(start, end, _path, updatedMap);
  }

  /// Removes the [key]:[newValue] pairing from the map, bearing in mind
  /// that it is a block Map.
  void _removeFromBlockMap(YamlNode keyNode, _ModifiableYamlNode valueNode) {
    var keySpan = keyNode.span;
    var valueSpan = valueNode.span;
    var start = _baseYaml._yaml.lastIndexOf('\n', keySpan.start.offset);
    var end = _baseYaml._yaml.indexOf('\n', valueSpan.end.offset);

    if (start == -1) start = 0;
    if (end == -1) end = _baseYaml._yaml.length - 1;

    var updatedMap = _clone();
    updatedMap.nodes.remove(keyNode);
    _baseYaml._removeRange(start, end, _path, updatedMap);
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
int _getContentSensitiveEnd(_ModifiableYamlNode node) {
  if (node is _ModifiableYamlList) {
    return _getContentSensitiveEnd(node.last as _ModifiableYamlNode);
  } else if (node is _ModifiableYamlMap) {
    return _getContentSensitiveEnd(node.values.last as _ModifiableYamlNode);
  }

  return node.span.end.offset;
}

/// Checks if the item is a Map or a List
bool _isCollection(Object item) => item is Map || item is List;

/// Creates a dummy [_ModifiableYamlNode] from a value. The span returned by this
/// function does not have any meaningful value.
_ModifiableYamlNode _dummyMYamlNodeFrom(
    Object value, YamlEditBuilder baseYaml, List<Object> path) {
  var yamlNode;

  if (value is List) {
    yamlNode = YamlList.wrap(value);
  } else if (value is Map) {
    yamlNode = YamlMap.wrap(value);
  } else {
    yamlNode = YamlScalar.wrap(value);
  }

  return _modifiedYamlNodeFrom(yamlNode, baseYaml, path);
}

/// Creates a [_ModifiableYamlNode] from a [YamlNode]. Returns the original object
/// if it is an instance of a [_ModifiableYamlNode].
_ModifiableYamlNode _modifiedYamlNodeFrom(
    YamlNode node, YamlEditBuilder baseYaml, List<Object> path) {
  switch (node.runtimeType) {
    case YamlList:
    case YamlListWrapper:
      return _ModifiableYamlList.from(node as YamlList, baseYaml, path);
    case YamlMap:
    case YamlMapWrapper:
      return _ModifiableYamlMap.from(node as YamlMap, baseYaml, path);
    case YamlScalar:
      return _ModifiableYamlScalar.from(node as YamlScalar, baseYaml);
    case _ModifiableYamlList:
    case _ModifiableYamlMap:
    case _ModifiableYamlScalar:
      return (node as _ModifiableYamlNode);
    default:
      throw UnsupportedError(
          'Cannot create ModifiableYamlNode from ${node.runtimeType}');
  }
}
