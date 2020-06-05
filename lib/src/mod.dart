import 'dart:collection' as collection;

import 'package:source_span/source_span.dart';
import 'package:yaml/src/equality.dart';
import 'package:yaml/yaml.dart';

dynamic loadYaml = (String yaml) => _YAML(yaml);

/// An interface for modifiable YAML documents which preserve Dart List and Map
/// interfaces. Every time a modification takes place, the string is re-parsed,
/// so users are guaranteed that calling toString() will result in valid YAML.
class _YAML {
  /// Original YAML string from which this instance is constructed.
  String yaml;

  /// Root node of YAML AST.
  // Definitely a _ModifiableYamlNode, but dynamic allows us to implement both
  // Map and List operations easily.
  dynamic _contents;

  static const int DEFAULT_INDENTATION = 2;

  _YAML(this.yaml) {
    var contents = loadYamlNode(yaml);
    _contents = _modifiedYamlNodeFrom(contents, this);
  }

  @override
  String toString() => yaml;

  // MARK - methods to simulate a List/Map interface.
  dynamic operator [](key) => _YAMLPath([key], this);
  operator []=(key, value) => _contents[key] = value;

  dynamic remove(Object value) => _contents.remove(value);
  dynamic removeAt(int index) => _contents.removeAt(index);

  dynamic get value => _contents.value;

  void add(Object value) => _contents.add(value);

  // MARK - methods that modifies and reloads the YAML
  void insert(int offset, String replacement) =>
      _replaceRange(offset, offset, replacement);

  void replaceRangeFromSpan(SourceSpan span, String replacement) {
    var start = span.start.offset;
    var end = span.end.offset;
    _replaceRange(start, end, replacement);
  }

  void _removeRange(int start, int end) => _replaceRange(start, end, '');

  void _replaceRange(int start, int end, String replacement) {
    yaml = yaml.replaceRange(start, end, replacement);
    var contents = loadYamlNode(yaml);
    _contents = _modifiedYamlNodeFrom(contents, this);
  }
}

/// Interface for a path of keys in a YAML document. This class only stores
/// the path from the root of a YAML document, and the value is only dynamically
/// obtained when the value method is called. When using this class, there is a
/// possibility that the YAML document has been modified in such a way that
/// this root becomes the child of a parent that does not exist in the YAML tree,
/// and can lead to errors when called.
class _YAMLPath {
  // Path from parent to current node.
  final List path;

  // Parent _YAML from which the path is defined
  final _YAML parent;

  _YAMLPath(this.path, this.parent);

  // Performs a "dynamic dispatch"
  dynamic get value {
    dynamic current = parent._contents;
    for (var elem in path) {
      current = current[elem];
      // TODO - null/error key checks
    }

    return current;
  }

  dynamic operator [](key) => _YAMLPath([...path, key], parent);

  operator []=(key, newValue) => value[key] = newValue;

  dynamic remove(Object toRemove) => value.remove(toRemove);
  dynamic removeAt(int index) => value.removeAt(index);

  void add(Object newValue) => value.add(newValue);

  @override
  String toString() {
    return value.toString();
  }
}

/// An interface for modifiable YAML nodes from a YAML AST.
// On top of the [YamlNode] elements, [_ModifiableYamlNode] also
// has the base [_YAML] object so that we can imitate modifications.
abstract class _ModifiableYamlNode extends YamlNode {
  SourceSpan _span;

  @override
  SourceSpan get span => _span;

  _YAML _baseYaml;
}

_ModifiableYamlNode _modifiedYamlNodeFrom(YamlNode node, _YAML baseYaml) {
  switch (node.runtimeType) {
    case YamlList:
      return _ModifiableYamlList.from(node as YamlList, baseYaml);
    case YamlMap:
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

class _ModifiableYamlScalar extends _ModifiableYamlNode {
  /// The [YamlScalar] from which this instance was created.
  final YamlScalar _yamlScalar;

  @override
  dynamic get value => _yamlScalar.value;

  _ModifiableYamlScalar.from(this._yamlScalar, _YAML baseYaml) {
    _span = _yamlScalar.span;
    _baseYaml = baseYaml;
  }

  @override
  String toString() => _yamlScalar.value.toString();
}

class _ModifiableYamlList extends _ModifiableYamlNode
    with collection.ListMixin {
  List<_ModifiableYamlNode> nodes;
  CollectionStyle style;

  @override
  int get length => nodes.length;
  @override
  set length(int index) =>
      throw UnsupportedError("This method shouldn't be called!");

  @override
  List get value => this;

  _ModifiableYamlList.from(YamlList yamlList, _YAML baseYaml) {
    _baseYaml = baseYaml;
    _span = yamlList.span;
    style = yamlList.style;

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
  void operator []=(int index, newValue) {
    var currValue = nodes[index];

    // TODO(walnut): list/map new values
    _baseYaml.replaceRangeFromSpan(currValue._span, newValue.toString());
  }

  @override
  _ModifiableYamlNode removeAt(int index) {
    var removedNode = nodes.removeAt(index);

    if (style == CollectionStyle.FLOW) {
      removeFromFlowList(removedNode._span, index);
    } else {
      removeFromBlockList(removedNode._span);
    }

    return removedNode;
  }

  @override
  bool remove(Object elem) {
    var index = indexOf(elem);
    if (index == -1) return false;

    removeAt(index);
    return true;
  }

  @override
  void add(Object elem) {
    if (style == CollectionStyle.FLOW) {
      addToFlowList(elem);
    } else {
      addToBlockList(elem);
    }
  }

  void removeFromFlowList(SourceSpan span, int index) {
    var start = span.start.offset;
    var end = span.end.offset;

    if (index == 0) {
      start = _baseYaml.yaml.lastIndexOf('[', start) + 1;
      end = _baseYaml.yaml.indexOf(RegExp(r',|]'), end) + 1;
    } else {
      start = _baseYaml.yaml.lastIndexOf(',', start);
    }

    _baseYaml._replaceRange(start, end, '');
  }

  void removeFromBlockList(SourceSpan span) {
    var start = _baseYaml.yaml.lastIndexOf('\n', span.start.offset);
    var end = _baseYaml.yaml.indexOf('\n', span.end.offset);
    _baseYaml._replaceRange(start, end, '');
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

  void addToFlowList(Object elem) {
    var valueString = getFlowString(elem);
    if (nodes.isNotEmpty) valueString = ', ' + valueString;

    _baseYaml.insert(span.end.offset - 1, valueString);
  }

  void addToBlockList(Object elem) {
    var valueString =
        getBlockString(elem, indentation + _YAML.DEFAULT_INDENTATION);
    var formattedValue = ''.padLeft(indentation) + '- ';

    if (isCollection(elem)) {
      formattedValue +=
          valueString.substring(indentation + _YAML.DEFAULT_INDENTATION) + '\n';
    } else {
      formattedValue += valueString + '\n';
    }
    _baseYaml._replaceRange(span.end.offset, span.end.offset, formattedValue);
  }
}

class _ModifiableYamlMap extends _ModifiableYamlNode with collection.MapMixin {
  @override
  int get length => nodes.length;

  Map<dynamic, _ModifiableYamlNode> nodes;

  CollectionStyle style;

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

  _ModifiableYamlMap.from(YamlMap yamlMap, _YAML baseYaml) {
    _span = yamlMap.span;
    _baseYaml = baseYaml;
    style = yamlMap.style;

    nodes = deepEqualsMap<dynamic, _ModifiableYamlNode>();
    for (var entry in yamlMap.nodes.entries) {
      nodes[entry.key] = _modifiedYamlNodeFrom(entry.value, baseYaml);
    }
  }

  @override
  _ModifiableYamlNode operator [](key) => nodes[key];

  @override
  void operator []=(key, newValue) {
    if (!nodes.containsKey(key)) {
      if (style == CollectionStyle.FLOW) {
        addToFlowMap(key, newValue);
      } else {
        addToBlockMap(key, newValue);
      }
    } else {
      if (style == CollectionStyle.FLOW) {
        replaceInFlowMap(key, newValue);
      } else {
        replaceInBlockMap(key, newValue);
      }
    }
  }

  YamlNode getKeyNode(Object key) {
    return (nodes.keys.firstWhere((node) => node.value == key) as YamlNode);
  }

  @override
  _ModifiableYamlNode remove(Object key) {
    if (!nodes.containsKey(key)) return null;

    var keyNode =
        (nodes.keys.firstWhere((node) => node.value == key) as YamlNode);
    var valueNode = nodes.remove(key);

    if (style == CollectionStyle.FLOW) {
      removeFromFlowMap(keyNode.span, valueNode.span, key);
    } else {
      removeFromBlockMap(keyNode.span, valueNode.span);
    }

    return valueNode;
  }

  @override
  Map get value => this;

  void addToFlowMap(Object key, Object newValue) {
    // The -1 accounts for the closing bracket.
    if (nodes.isEmpty) {
      _baseYaml.insert(span.end.offset - 1, '$key: $newValue');
    } else {
      _baseYaml.insert(span.end.offset - 1, ', $key: $newValue');
    }
  }

  void addToBlockMap(Object key, Object newValue) {
    var valueString =
        getBlockString(newValue, indentation + _YAML.DEFAULT_INDENTATION);
    var formattedValue = ' ' * indentation + '$key: ';
    var offset = span.end.offset;

    // Adjusts offset to after the trailing newline of the last entry, if it exists
    if (nodes.isNotEmpty) {
      var lastValueSpanEnd = nodes.values.last._span.end.offset;
      var nextNewLineIndex = _baseYaml.yaml.indexOf('\n', lastValueSpanEnd);

      if (nextNewLineIndex != -1) offset = nextNewLineIndex + 1;
    }

    if (isCollection(newValue)) formattedValue += '\n';

    formattedValue += valueString + '\n';
    _baseYaml.insert(offset, formattedValue);
  }

  void replaceInFlowMap(Object key, Object newValue) {
    var valueSpan = nodes[key].span;
    var valueString = getFlowString(newValue);

    if (isCollection(newValue)) valueString = '\n' + valueString;
    _baseYaml.replaceRangeFromSpan(valueSpan, valueString);
  }

  void replaceInBlockMap(Object key, Object newValue) {
    var value = nodes[key];
    var valueString =
        getBlockString(newValue, indentation + _YAML.DEFAULT_INDENTATION);
    var start = getKeyNode(key).span.end.offset + 2;
    var end = _getContentSensitiveEnd(value);

    if (isCollection(newValue)) valueString = '\n' + valueString;

    _baseYaml._replaceRange(start, end, valueString);
  }

  @override
  void clear() => _baseYaml.replaceRangeFromSpan(span, '');

  @override
  Iterable get keys => nodes.keys.map((node) => node.value);

  void removeFromFlowMap(SourceSpan keySpan, SourceSpan valueSpan, Object key) {
    var start = keySpan.start.offset;
    var end = valueSpan.end.offset;

    if (deepEquals(key, nodes.keys.first)) {
      start = _baseYaml.yaml.lastIndexOf('{', start) + 1;
      end = _baseYaml.yaml.indexOf(RegExp(r',|}'), end) + 1;
    } else {
      start = _baseYaml.yaml.lastIndexOf(',', start);
    }

    _baseYaml._removeRange(start, end);
  }

  void removeFromBlockMap(SourceSpan keySpan, SourceSpan valueSpan) {
    var start = _baseYaml.yaml.lastIndexOf('\n', keySpan.start.offset);
    var end = _baseYaml.yaml.indexOf('\n', valueSpan.end.offset);
    _baseYaml._removeRange(start, end);
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
String getBlockString(Object value, [int indentation = 0]) {
  if (value is List) {
    return value.map((e) => ' ' * indentation + '- $e').join('\n');
  } else if (value is Map) {
    return value.entries.map((entry) {
      var result = ' ' * indentation + '${entry.key}:';

      if (!isCollection(entry.value)) return result + ' ${entry.value}';

      return '$result\n' +
          getBlockString(entry.value, indentation + _YAML.DEFAULT_INDENTATION);
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

bool isCollection(Object item) => item is Map || item is List;
