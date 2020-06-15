import 'package:yaml/src/equality.dart';
import 'package:yaml/yaml.dart';

import './source_edit.dart';
import './style.dart';
import './utils.dart';

/// Performs the string operation on [yaml] to achieve the effect of setting
/// the element at [key] to [newValue] when re-parsed.
SourceEdit setInMap(
    String yaml, YamlMap map, Object key, Object newValue, YamlStyle style) {
  if (!map.nodes.containsKey(key)) {
    if (map.style == CollectionStyle.FLOW) {
      return addToFlowMap(yaml, map, key, newValue, style);
    } else {
      return addToBlockMap(yaml, map, key, newValue, style);
    }
  } else {
    if (map.style == CollectionStyle.FLOW) {
      return replaceInFlowMap(yaml, map, key, newValue, style);
    } else {
      return replaceInBlockMap(yaml, map, key, newValue, style);
    }
  }
}

/// Performs the string operation on [yaml] to achieve the effect of removing
/// the element at [key] to [newValue] when re-parsed.
///
/// Returns the [YamlNode] removed.
SourceEdit removeInMap(String yaml, YamlMap map, Object key) {
  if (!map.nodes.containsKey(key)) return null;

  final keyNode = getKeyNode(map, key);
  final valueNode = map.nodes[key];

  if (map.style == CollectionStyle.FLOW) {
    return removeFromFlowMap(yaml, map, keyNode, valueNode);
  } else {
    return removeFromBlockMap(yaml, map, keyNode, valueNode);
  }
}

/// Returns the [YamlNode] corresponding to the provided [key].
YamlNode getKeyNode(YamlMap map, Object key) {
  return (map.nodes.keys.firstWhere((node) => deepEquals(node, key))
      as YamlNode);
}

/// Gets the indentation level of the map. This is 0 if it is a flow map,
/// but returns the number of spaces before the keys for block maps.
int getMapIndentation(String yaml, YamlMap map) {
  if (map.style == CollectionStyle.FLOW) return 0;

  /// An empty block map doesn't really exist.
  if (map.nodes.isEmpty) {
    throw UnsupportedError('Unable to get indentation for empty block list');
  }

  final lastKey = map.nodes.keys.last as YamlNode;
  final lastSpanOffset = lastKey.span.start.offset;
  var lastNewLine = yaml.lastIndexOf('\n', lastSpanOffset);
  if (lastNewLine == -1) return lastSpanOffset;

  return lastSpanOffset - lastNewLine - 1;
}

/// Returns a new [YamlMap] constructed by applying [update] onto the [nodes]
/// of this [YamlMap].
YamlMap updatedYamlMap(YamlMap map, Function(Map<dynamic, YamlNode>) update) {
  final dummyMap = {...map.nodes};
  update(dummyMap);

  final updatedMap = {};

  /// This workaround is necessary since `_yamlNodeFrom` will re-wrap `YamlNodes`,
  /// so we need to unwrap them before passing them in.
  for (var key in dummyMap.keys) {
    var keyValue = key.value;

    updatedMap[keyValue] = dummyMap[key];
  }

  return yamlNodeFrom(updatedMap);
}

/// Performs the string operation on [yaml] to achieve the effect of adding
/// the [key]:[newValue] pair when reparsed, bearing in mind that this is a flow map.
SourceEdit addToFlowMap(
    String yaml, YamlMap map, Object key, Object newValue, YamlStyle style) {
  final keyString = getFlowString(key);
  final valueString = getFlowString(newValue);

  // The -1 accounts for the closing bracket.
  if (map.nodes.isEmpty) {
    return SourceEdit(map.span.end.offset - 1, 0, '$keyString: $valueString');
  } else {
    return SourceEdit(map.span.end.offset - 1, 0, ', $keyString: $valueString');
  }
}

/// Performs the string operation on [yaml] to achieve the effect of adding
/// the [key]:[newValue] pair when reparsed, bearing in mind that this is a block map.
SourceEdit addToBlockMap(
    String yaml, YamlMap map, Object key, Object newValue, YamlStyle style) {
  final keyString = getFlowString(key);
  final valueString = getBlockString(
      newValue, getMapIndentation(yaml, map) + style.indentationStep);
  var formattedValue = ' ' * getMapIndentation(yaml, map) + '$keyString: ';
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

  if (isCollection(newValue)) formattedValue += '\n';

  formattedValue += valueString + '\n';

  return SourceEdit(offset, 0, formattedValue);
}

/// Performs the string operation on [yaml] to achieve the effect of replacing
/// the value at [key] with [newValue] when reparsed, bearing in mind that this is a
/// flow map.

SourceEdit replaceInFlowMap(
    String yaml, YamlMap map, Object key, Object newValue, YamlStyle style) {
  final valueSpan = map.nodes[key].span;
  var valueString = getFlowString(newValue);

  if (isCollection(newValue)) valueString = '\n' + valueString;

  return SourceEdit(valueSpan.start.offset,
      valueSpan.end.offset - valueSpan.start.offset, valueString);
}

/// Performs the string operation on [yaml] to achieve the effect of replacing
/// the value at [key] with [newValue] when reparsed, bearing in mind that this is a
/// block map.
SourceEdit replaceInBlockMap(
    String yaml, YamlMap map, Object key, Object newValue, YamlStyle style) {
  final value = map.nodes[key];
  final keyNode = getKeyNode(map, key);
  var valueString = getBlockString(
      newValue, getMapIndentation(yaml, map) + style.indentationStep);

  /// +2 accounts for the colon
  final start = keyNode.span.end.offset + 2;
  final end = getContentSensitiveEnd(value);

  if (isCollection(newValue)) valueString = '\n' + valueString;

  return SourceEdit(start, end - start, valueString);
}

/// Performs the string operation on [yaml] to achieve the effect of removing
/// the [key] from the map, bearing in mind that this is a flow map.
SourceEdit removeFromFlowMap(
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
SourceEdit removeFromBlockMap(
    String yaml, YamlMap map, YamlNode keyNode, YamlNode valueNode) {
  var keySpan = keyNode.span;
  var valueSpan = valueNode.span;
  var start = yaml.lastIndexOf('\n', keySpan.start.offset);
  var end = yaml.indexOf('\n', valueSpan.end.offset);

  if (start == -1) start = 0;
  if (end == -1) end = yaml.length - 1;

  return SourceEdit(start, end - start, '');
}
