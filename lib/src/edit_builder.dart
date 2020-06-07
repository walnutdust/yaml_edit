import 'dart:collection' as collection;
import 'dart:convert';

import 'package:source_span/source_span.dart';
import 'package:yaml/src/equality.dart';
import 'package:yaml/src/yaml_node_wrapper.dart';
import 'package:yaml/yaml.dart';

/// An interface for modifiable YAML documents which preserve Dart List and Map
/// interfaces. Every time a modification takes place, the string is re-parsed,
/// so users are guaranteed that calling toString() will result in valid YAML.
class YamlEditBuilder {
  final List<SourceEdit> _edits = [];
  List<SourceEdit> get edits => [..._edits];

  /// Original YAML string from which this instance is constructed.
  String yaml;

  /// Root node of YAML AST.
  /// Definitely a _ModifiableYamlNode, but dynamic allows us to implement both
  /// Map and List operations easily.
  dynamic _contents;

  int indentationStep;

  YamlEditBuilder(this.yaml, {this.indentationStep = 2}) {
    var contents = loadYamlNode(yaml);
    _contents = _modifiedYamlNodeFrom(contents, this);
  }

  @override
  String toString() => yaml;

  /// Traverses down the provided [path] to the second-last node in the [path].
  dynamic _getToBeforeLast(List<dynamic> path) {
    var current = _contents;
    // Traverse down the path list via indexes because we want to avoid the last
    // key. We cannot use a for-in loop to check the value of the last element
    // because it might be a primitive and repeated as a previous key.
    for (var i = 0; i < path.length - 1; i++) {
      current = current[path[i]];
    }

    return current;
  }

  /// Gets the element represented by the [path].
  dynamic _getElemInPath(List<dynamic> path) {
    if (path.isEmpty) {
      return _contents;
    }
    var current = _getToBeforeLast(path);
    return current[path.last];
  }

  /// Gets the value of the element represented by the [path]. If the element is
  /// null, we return null.
  dynamic getIn(List<dynamic> path) {
    var elem = _getElemInPath(path);
    if (elem == null) return null;
    return elem.value;
  }

  /// Sets [value] in the [path]. If the [path] is not accessible (e.g. it currently
  /// does not exist in the document), an error will be thrown.
  void setIn(List<dynamic> path, dynamic value) {
    var current = _getToBeforeLast(path);
    var lastNode = path.last;
    current[lastNode] = value;
  }

  /// Appends [value] into the list at [listPath], only if the element at the given path
  /// is a List.
  void addInList(List<dynamic> listPath, dynamic value) {
    var elem = _getElemInPath(listPath);
    elem.add(value);
  }

  /// Prepends [value] into the list at [listPath], only if the element at the given path
  /// is a List.
  void prependInList(List<dynamic> listPath, dynamic value) {
    var elem = _getElemInPath(listPath);
    elem.prepend(value);
  }

  /// Inserts [value] into the list at [listPath], only if the element at the given path
  /// is a list. [index] must be non-negative and no greater than the list's length.
  void insertInList(List<dynamic> listPath, int index, dynamic value) {
    var elem = _getElemInPath(listPath);
    elem.insert(index, value);
  }

  /// Removes the value in the path.
  void removeIn(List<dynamic> path) {
    var current = _getToBeforeLast(path);
    var lastNode = path.last;

    if (current is _ModifiableYamlList) {
      current.removeAt(lastNode);
    } else {
      current.remove(lastNode);
    }
  }

  /// Utility method to insert [replacement] at [offset] on [yaml].
  void _insert(int offset, String replacement, void Function() change) =>
      _replaceRange(offset, offset, replacement, change);

  /// Utility method to replace the substring in [yaml] as denoted by
  /// the start and end of [span] with [replacement].
  void replaceRangeFromSpan(
      SourceSpan span, String replacement, void Function() change) {
    var start = span.start.offset;
    var end = span.end.offset;
    _replaceRange(start, end, replacement, change);
  }

  /// Utility method to remove the substring of [yaml] within the range
  /// provided by [start] and [end].
  void _removeRange(int start, int end, void Function() change) =>
      _replaceRange(start, end, '', change);

  /// Utility method to replace the substring of [yaml] within the range
  /// provided by [start] and [end] with [replacement], and then reloading
  /// the data structure represented by [yaml].
  void _replaceRange(
      int start, int end, String replacement, void Function() change) {
    yaml = yaml.replaceRange(start, end, replacement);
    var contents = loadYamlNode(yaml);
    var modifiableContents = _modifiedYamlNodeFrom(contents, this);

    change();
    if (_contents != modifiableContents) {
      throw Exception(
          'Modification did not result in expected result! Obtained: \n$modifiableContents\nExpected: \n$_contents');
    }

    _contents = modifiableContents;
    _edits.add(SourceEdit(start, end - start, replacement));
  }
}

/// An interface for modifiable YAML nodes from a YAML AST.
/// On top of the [YamlNode] elements, [_ModifiableYamlNode] also
/// has the base [YamlEditBuilder] object so that we can imitate modifications.
abstract class _ModifiableYamlNode extends YamlNode {
  SourceSpan _span;

  @override
  SourceSpan get span => _span;

  YamlEditBuilder _baseYaml;
}

/// Creates a [_ModifiableYamlNode] from a [YamlNode]. Returns the original object
/// if it is an instance of a [_ModifiableYamlNode].
_ModifiableYamlNode _modifiedYamlNodeFrom(
    YamlNode node, YamlEditBuilder baseYaml) {
  switch (node.runtimeType) {
    case YamlList:
    case YamlListWrapper:
      return _ModifiableYamlList.from(node as YamlList, baseYaml);
    case YamlMap:
    case YamlMapWrapper:
      return _ModifiableYamlMap.from(node as YamlMap, baseYaml);
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

/// Creates a dummy [_ModifiableYamlNode] from a value.
_ModifiableYamlNode _dummyMYamlNodeFrom(
    dynamic value, YamlEditBuilder baseYaml) {
  var yamlNode;

  if (value is List) {
    yamlNode = YamlList.wrap(value);
  } else if (value is Map) {
    yamlNode = YamlMap.wrap(value);
  } else {
    yamlNode = YamlScalar.wrap(value);
  }

  return _modifiedYamlNodeFrom(yamlNode, baseYaml);
}

/// A wrapped scalar parsed from YAML.
class _ModifiableYamlScalar extends _ModifiableYamlNode {
  /// The [YamlScalar] from which this instance was created.
  final YamlScalar _yamlScalar;

  @override
  dynamic get value => _yamlScalar.value;

  _ModifiableYamlScalar.from(this._yamlScalar, YamlEditBuilder baseYaml) {
    _span = _yamlScalar.span;
    _baseYaml = baseYaml;
  }

  @override
  String toString() => _yamlScalar.value.toString();

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
  List<_ModifiableYamlNode> nodes;

  final CollectionStyle style;

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
  _ModifiableYamlList.from(YamlList yamlList, YamlEditBuilder baseYaml)
      : style = yamlList.style {
    _baseYaml = baseYaml;
    _span = yamlList.span;

    nodes = [];
    for (var node in yamlList.nodes) {
      nodes.add(_modifiedYamlNodeFrom(node, _baseYaml));
    }
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
    var lastNewLine = _baseYaml.yaml.lastIndexOf('\n', lastSpanOffset);
    if (lastNewLine == -1) lastNewLine = 0;
    var lastHyphen = _baseYaml.yaml.lastIndexOf('-', lastSpanOffset);

    return lastHyphen - lastNewLine - 1;
  }

  @override
  _ModifiableYamlNode operator [](int index) => nodes[index];

  @override
  void operator []=(int index, dynamic newValue) {
    var currValue = nodes[index];
    _baseYaml.replaceRangeFromSpan(currValue._span, newValue.toString(), () {
      nodes[index] = _dummyMYamlNodeFrom(newValue, _baseYaml);
    });
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
  bool remove(dynamic elem) {
    var index = indexOf(elem);
    if (index == -1) return false;

    removeAt(index);
    return true;
  }

  /// Adds [elem] to the end of the list.
  @override
  void add(dynamic elem) {
    if (style == CollectionStyle.FLOW) {
      _addToFlowList(elem);
    } else {
      _addToBlockList(elem);
    }
  }

  /// Adds [elem] to the start of the list.
  void prepend(dynamic elem) {
    if (style == CollectionStyle.FLOW) {
      _prependToFlowList(elem);
    } else {
      _prependToBlockList(elem);
    }
  }

  /// Adds [elem] to the list at [index]. [index] should be non-negative and
  /// no more than [length].
  @override
  void insert(int index, dynamic elem) {
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
      start = _baseYaml.yaml.lastIndexOf('[', start) + 1;
      end = _baseYaml.yaml.indexOf(RegExp(r',|]'), end) + 1;
    } else {
      start = _baseYaml.yaml.lastIndexOf(',', start);
    }

    _baseYaml._replaceRange(start, end, '', () => nodes.removeAt(index));
  }

  /// Performs the removal of [removedNode] from the base yaml, noting that
  /// the current list is a block list.
  void _removeFromBlockList(_ModifiableYamlNode removedNode, int index) {
    var span = removedNode._span;
    var start = _baseYaml.yaml.lastIndexOf('\n', span.start.offset);
    var end = _baseYaml.yaml.indexOf('\n', span.end.offset);
    _baseYaml._replaceRange(start, end, '', () => nodes.removeAt(index));
  }

  /// Overriding indexOf to provide deep equality, allowing users to remove
  /// elements by the values rather than requiring them to construct
  /// [_ModifiableYamlNode]s
  @override
  int indexOf(dynamic element, [int start = 0]) {
    if (start < 0) start = 0;
    for (var i = start; i < length; i++) {
      if (deepEquals(this[i].value, element)) return i;
    }
    return -1;
  }

  /// Performs the prepending of [elem] into the base yaml, noting that the current
  /// list is a flow list.
  void _prependToFlowList(dynamic elem) {
    var valueString = getFlowString(elem);
    if (nodes.isNotEmpty) valueString = '$valueString, ';

    _baseYaml._insert(span.start.offset + 1, valueString, () {
      var elemModifiableYAMLNode = _dummyMYamlNodeFrom(elem, _baseYaml);
      nodes.insert(0, elemModifiableYAMLNode);
    });
  }

  /// Performs the prepending of [elem] into the base yaml, noting that the current
  /// list is a block list.
  void _prependToBlockList(dynamic elem) {
    var valueString =
        getBlockString(elem, indentation + _baseYaml.indentationStep);
    var formattedValue = ''.padLeft(indentation) + '- ';

    if (isCollection(elem)) {
      formattedValue +=
          valueString.substring(indentation + _baseYaml.indentationStep) + '\n';
    } else {
      formattedValue += valueString + '\n';
    }

    var startOffset = _baseYaml.yaml.lastIndexOf('\n', span.start.offset) + 1;

    _baseYaml._insert(startOffset, formattedValue, () {
      var elemModifiableYAMLNode = _dummyMYamlNodeFrom(elem, _baseYaml);
      nodes.insert(0, elemModifiableYAMLNode);
    });
  }

  /// Performs the prepending of [elem] into the base yaml, noting that the current
  /// list is a flow list. [index] should be non-negative and less than or equal
  /// to [length].
  void _insertInFlowList(int index, dynamic elem) {
    if (index < 0 || index > length) {
      throw RangeError.range(index, 0, length);
    }
    if (index == length) return _addToFlowList(elem);
    if (index == 0) return _prependToFlowList(elem);

    var valueString = ' ' + getFlowString(elem);
    if (nodes.isNotEmpty) valueString = '$valueString,';

    var currNode = nodes[index];
    var currNodeStartIdx = currNode.span.start.offset;
    var startOffset =
        _baseYaml.yaml.lastIndexOf(RegExp(r',|\['), currNodeStartIdx) + 1;

    _baseYaml._insert(startOffset, valueString, () {
      var elemModifiableYAMLNode = _dummyMYamlNodeFrom(elem, _baseYaml);
      nodes.insert(index, elemModifiableYAMLNode);
    });
  }

  /// Performs the prepending of [elem] into the base yaml, noting that the current
  /// list is a block list. [index] should be non-negative and less than or equal
  /// to [length].
  void _insertInBlockList(int index, dynamic elem) {
    if (index < 0 || index > length) {
      throw RangeError.range(index, 0, length);
    }
    if (index == length) return _addToBlockList(elem);
    if (index == 0) return _prependToBlockList(elem);

    var valueString =
        getBlockString(elem, indentation + _baseYaml.indentationStep);
    var formattedValue = ''.padLeft(indentation) + '- ';

    if (isCollection(elem)) {
      formattedValue +=
          valueString.substring(indentation + _baseYaml.indentationStep) + '\n';
    } else {
      formattedValue += valueString + '\n';
    }

    var currNode = nodes[index];
    var currNodeStartIdx = currNode.span.start.offset;
    var startOffset = _baseYaml.yaml.lastIndexOf('\n', currNodeStartIdx) + 1;

    _baseYaml._insert(startOffset, formattedValue, () {
      var elemModifiableYAMLNode = _dummyMYamlNodeFrom(elem, _baseYaml);
      nodes.insert(index, elemModifiableYAMLNode);
    });
  }

  /// Performs the addition of [elem] into the base yaml, noting that the current
  /// list is a flow list.
  void _addToFlowList(dynamic elem) {
    var valueString = getFlowString(elem);
    if (nodes.isNotEmpty) valueString = ', ' + valueString;

    _baseYaml._insert(span.end.offset - 1, valueString, () {
      var elemModifiableYAMLNode = _dummyMYamlNodeFrom(elem, _baseYaml);
      nodes.add(elemModifiableYAMLNode);
    });
  }

  /// Performs the addition of [elem] into the base yaml, noting that the current
  /// list is a block list.
  void _addToBlockList(dynamic elem) {
    var valueString =
        getBlockString(elem, indentation + _baseYaml.indentationStep);
    var formattedValue = ''.padLeft(indentation) + '- ';

    if (isCollection(elem)) {
      formattedValue +=
          valueString.substring(indentation + _baseYaml.indentationStep) + '\n';
    } else {
      formattedValue += valueString + '\n';
    }

    // Adjusts offset to after the trailing newline of the last entry, if it exists
    if (nodes.isNotEmpty) {
      var lastValueSpanEnd = nodes.last._span.end.offset;
      var nextNewLineIndex = _baseYaml.yaml.indexOf('\n', lastValueSpanEnd);
      if (nextNewLineIndex == -1) {
        formattedValue = '\n' + formattedValue;
      }
    }

    _baseYaml._insert(span.end.offset, formattedValue, () {
      var elemModifiableYAMLNode = _dummyMYamlNodeFrom(elem, _baseYaml);
      nodes.add(elemModifiableYAMLNode);
    });
  }
}

/// A wrapped map parsed from YAML, extended with methods to allow modification
/// on the base YAML document.
class _ModifiableYamlMap extends _ModifiableYamlNode with collection.MapMixin {
  @override
  int get length => nodes.length;

  Map<dynamic, _ModifiableYamlNode> nodes;

  final CollectionStyle style;

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
    var lastNewLine = _baseYaml.yaml.lastIndexOf('\n', lastSpanOffset);
    if (lastNewLine == -1) lastNewLine = 0;

    return lastSpanOffset - lastNewLine - 1;
  }

  _ModifiableYamlMap.from(YamlMap yamlMap, YamlEditBuilder baseYaml)
      : style = yamlMap.style {
    _span = yamlMap.span;
    _baseYaml = baseYaml;

    nodes = deepEqualsMap<dynamic, _ModifiableYamlNode>();
    for (var entry in yamlMap.nodes.entries) {
      nodes[entry.key] = _modifiedYamlNodeFrom(entry.value, baseYaml);
    }
  }

  @override
  _ModifiableYamlNode operator [](dynamic key) => nodes[key];

  @override
  void operator []=(dynamic key, dynamic newValue) {
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
  YamlNode getKeyNode(dynamic key) {
    return (nodes.keys.firstWhere((node) => node.value == key) as YamlNode);
  }

  @override
  _ModifiableYamlNode remove(dynamic key) {
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
  void _addToFlowMap(dynamic key, dynamic newValue) {
    var keyNode = _dummyMYamlNodeFrom(key, _baseYaml);
    var valueNode = _dummyMYamlNodeFrom(newValue, _baseYaml);
    // The -1 accounts for the closing bracket.
    if (nodes.isEmpty) {
      _baseYaml._insert(span.end.offset - 1, '$key: $newValue', () {
        nodes[keyNode] = valueNode;
      });
    } else {
      nodes[keyNode] = valueNode;
      _baseYaml._insert(span.end.offset - 1, ', $key: $newValue', () {
        nodes[keyNode] = valueNode;
      });
    }
  }

  /// Adds the [key]:[newValue] pairing into the map, bearing in mind
  /// that it is a block Map.
  void _addToBlockMap(dynamic key, dynamic newValue) {
    var valueString =
        getBlockString(newValue, indentation + _baseYaml.indentationStep);
    var formattedValue = ' ' * indentation + '$key: ';
    var offset = span.end.offset;

    // Adjusts offset to after the trailing newline of the last entry, if it exists
    if (nodes.isNotEmpty) {
      var lastValueSpanEnd = nodes.values.last._span.end.offset;
      var nextNewLineIndex = _baseYaml.yaml.indexOf('\n', lastValueSpanEnd);

      if (nextNewLineIndex != -1) {
        offset = nextNewLineIndex + 1;
      } else {
        formattedValue = '\n' + formattedValue;
      }
    }

    if (isCollection(newValue)) formattedValue += '\n';

    formattedValue += valueString + '\n';

    _baseYaml._insert(offset, formattedValue, () {
      var keyNode = _dummyMYamlNodeFrom(key, _baseYaml);
      var valueNode = _dummyMYamlNodeFrom(newValue, _baseYaml);
      nodes[keyNode] = valueNode;
    });
  }

  /// Updates the [key]:[newValue] pairing into the map, bearing in mind
  /// that it is a flow Map.
  void _replaceInFlowMap(dynamic key, dynamic newValue) {
    var valueSpan = nodes[key].span;
    var valueString = getFlowString(newValue);

    if (isCollection(newValue)) valueString = '\n' + valueString;

    _baseYaml.replaceRangeFromSpan(valueSpan, valueString, () {
      var valueNode = _dummyMYamlNodeFrom(newValue, _baseYaml);
      nodes[key] = valueNode;
    });
  }

  /// Updates the [key]:[newValue] pairing into the map, bearing in mind
  /// that it is a block Map.
  void _replaceInBlockMap(dynamic key, dynamic newValue) {
    var value = nodes[key];
    var valueString =
        getBlockString(newValue, indentation + _baseYaml.indentationStep);
    var start = getKeyNode(key).span.end.offset + 2;
    var end = _getContentSensitiveEnd(value);

    if (isCollection(newValue)) valueString = '\n' + valueString;

    _baseYaml._replaceRange(start, end, valueString, () {
      var valueNode = _dummyMYamlNodeFrom(newValue, _baseYaml);
      nodes[key] = valueNode;
    });
  }

  @override
  void clear() {
    _baseYaml.replaceRangeFromSpan(span, '', () => nodes.clear());
  }

  @override
  Iterable get keys => nodes.keys.map((node) => node.value);

  /// Removes the [key]:[newValue] pairing from the map, bearing in mind
  /// that it is a flow Map.
  void _removeFromFlowMap(
      YamlNode keyNode, _ModifiableYamlNode valueNode, Object key) {
    var keySpan = keyNode.span;
    var valueSpan = valueNode.span;
    var start = keySpan.start.offset;
    var end = valueSpan.end.offset;

    if (deepEquals(key, nodes.keys.first)) {
      start = _baseYaml.yaml.lastIndexOf('{', start) + 1;
      end = _baseYaml.yaml.indexOf(RegExp(r',|}'), end) + 1;
    } else {
      start = _baseYaml.yaml.lastIndexOf(',', start);
    }

    _baseYaml._removeRange(start, end, () => nodes.remove(keyNode));
  }

  /// Removes the [key]:[newValue] pairing from the map, bearing in mind
  /// that it is a block Map.
  void _removeFromBlockMap(YamlNode keyNode, _ModifiableYamlNode valueNode) {
    var keySpan = keyNode.span;
    var valueSpan = valueNode.span;
    var start = _baseYaml.yaml.lastIndexOf('\n', keySpan.start.offset);
    var end = _baseYaml.yaml.indexOf('\n', valueSpan.end.offset);

    if (start == -1) start = 0;
    if (end == -1) end = _baseYaml.yaml.length - 1;
    _baseYaml._removeRange(start, end, () => nodes.remove(keyNode));
  }
}

/// Returns a safe string by checking for strings that begin with > or |
String getSafeString(String string) {
  if (string.startsWith('>') || string.startsWith('|')) {
    return '\'$string\'';
  }

  return string;
}

/// Returns values as strings representing flow objects.
String getFlowString(Object value) {
  return getSafeString(value.toString());
}

/// Returns values as strings representing block objects.
// We do a join('\n') rather than having it in the mapping to avoid
// adding additional spaces when updating rather than adding elements.
String getBlockString(Object value,
    [int indentation = 0, int additionalIndentation = 2]) {
  if (value is List) {
    return value.map((e) => ' ' * indentation + '- $e').join('\n');
  } else if (value is Map) {
    return value.entries.map((entry) {
      var result = ' ' * indentation + '${entry.key}:';

      if (!isCollection(entry.value)) return result + ' ${entry.value}';

      return '$result\n' +
          getBlockString(entry.value, indentation + additionalIndentation);
    }).join('\n');
  }

  return getSafeString(value.toString());
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
bool isCollection(Object item) => item is Map || item is List;

/// A class representing a change on a String
class SourceEdit {
  final int offset;
  final int length;
  final String replacement;

  SourceEdit(this.offset, this.length, this.replacement);

  @override
  bool operator ==(other) {
    return offset == other.offset &&
        length == other.length &&
        replacement == other.replacement;
  }

  /// Constructs a SourceEdit from a json-encoded String.
  factory SourceEdit.fromJson(String json) {
    var jsonEdit = jsonDecode(json);

    if (jsonEdit is Map) {
      int offset;
      if (jsonEdit.containsKey('offset') &&
          jsonEdit.containsKey('length') &&
          jsonEdit.containsKey('replacement')) {
        offset = (jsonEdit['offset'] as int);
      }
      int length;
      if (jsonEdit.containsKey('length')) {
        length = (jsonEdit['length'] as int);
      }
      String replacement;
      if (jsonEdit.containsKey('replacement')) {
        replacement = (jsonEdit['replacement'] as String);
      }
      return SourceEdit(offset, length, replacement);
    } else {
      throw Exception('Invalid JSON passed to SourceEdit');
    }
  }

  /// Encodes this object in JSON.
  String toJSON() {
    var map = {'offset': offset, 'length': length, 'replacement': replacement};

    return jsonEncode(map);
  }

  @override
  String toString() => toJSON();

  /// Applies a series of [SourceEdit]s to an original string, and return the final output
  static String apply(String original, List<SourceEdit> edits) {
    var current = original;
    for (var edit in edits) {
      current = current.replaceRange(
          edit.offset, edit.offset + edit.length, edit.replacement);
    }

    return current;
  }
}