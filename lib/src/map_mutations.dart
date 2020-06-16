import 'package:yaml/src/equality.dart' show deepEqualsMap;
import 'package:yaml/yaml.dart';

import './source_edit.dart';
import './style.dart';
import './utils.dart';

/// Performs the string operation on [yaml] to achieve the effect of setting
/// the element at [key] to [newValue] when re-parsed.
SourceEdit assignInMap(
    String yaml, YamlMap map, Object key, Object newValue, YamlStyle style) {
  if (!containsKey(map, key)) {
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
SourceEdit removeInMap(String yaml, YamlMap map, Object key) {
  if (!containsKey(map, key)) return null;

  final keyNode = getKeyNode(map, key);
  final valueNode = map.nodes[key];

  if (map.style == CollectionStyle.FLOW) {
    return _removeFromFlowMap(yaml, map, keyNode, valueNode);
  } else {
    return _removeFromBlockMap(yaml, map, keyNode, valueNode);
  }
}

/// Gets the indentation level of the map. This is 0 if it is a flow map,
/// but returns the number of spaces before the keys for block maps.
int getMapIndentation(String yaml, YamlMap map) {
  if (map.style == CollectionStyle.FLOW) return 0;

  /// An empty block map doesn't really exist.
  if (map.isEmpty) {
    throw UnsupportedError('Unable to get indentation for empty block list');
  }

  /// Use the number of spaces between the last key and the newline as indentation.
  final lastKey = map.nodes.keys.last as YamlNode;
  final lastSpanOffset = lastKey.span.start.offset;
  final lastNewLine = yaml.lastIndexOf('\n', lastSpanOffset);
  if (lastNewLine == -1) return lastSpanOffset;

  return lastSpanOffset - lastNewLine - 1;
}

/// Returns a new [YamlMap] constructed by applying [update] onto the [nodes]
/// of this [YamlMap].
YamlMap updatedYamlMap(YamlMap map, Function(Map) update) {
  final dummyMap = deepEqualsMap();
  dummyMap.addAll(map.nodes);

  update(dummyMap);
  final updatedMap = {};

  /// This workaround is necessary since `_yamlNodeFrom` will re-wrap `YamlNodes`,
  /// so we need to unwrap them before passing them in.
  for (var key in dummyMap.keys) {
    updatedMap[key.value] = dummyMap[key].value;
  }

  return yamlNodeFrom(updatedMap);
}

/// Performs the string operation on [yaml] to achieve the effect of adding
/// the [key]:[newValue] pair when reparsed, bearing in mind that this is a flow map.
SourceEdit _addToFlowMap(
    String yaml, YamlMap map, Object key, Object newValue, YamlStyle style) {
  final keyString = getFlowString(key);
  final valueString = getFlowString(newValue);

  // The -1 accounts for the closing bracket.
  if (map.isEmpty) {
    return SourceEdit(map.span.end.offset - 1, 0, '$keyString: $valueString');
  } else {
    return SourceEdit(map.span.end.offset - 1, 0, ', $keyString: $valueString');
  }
}

/// Performs the string operation on [yaml] to achieve the effect of adding
/// the [key]:[newValue] pair when reparsed, bearing in mind that this is a block map.
SourceEdit _addToBlockMap(
    String yaml, YamlMap map, Object key, Object newValue, YamlStyle style) {
  final newIndentation = getMapIndentation(yaml, map) + style.indentationStep;
  final keyString = getFlowString(key);
  final valueString = getBlockString(newValue, newIndentation);
  var formattedValue = ' ' * getMapIndentation(yaml, map) + '$keyString: ';
  var offset = map.span.end.offset;

  // Adjusts offset to after the trailing newline of the last entry, if it exists
  if (map.isNotEmpty) {
    final lastValueSpanEnd = getContentSensitiveEnd(map.nodes.values.last);
    final nextNewLineIndex = yaml.indexOf('\n', lastValueSpanEnd);

    if (nextNewLineIndex != -1) {
      offset = nextNewLineIndex + 1;
    } else {
      formattedValue = '\n' + formattedValue;
    }
  }

  formattedValue += valueString + '\n';

  return SourceEdit(offset, 0, formattedValue);
}

/// Performs the string operation on [yaml] to achieve the effect of replacing
/// the value at [key] with [newValue] when reparsed, bearing in mind that this is a
/// flow map.
SourceEdit _replaceInFlowMap(
    String yaml, YamlMap map, Object key, Object newValue, YamlStyle style) {
  final valueSpan = map.nodes[key].span;
  final valueString = getFlowString(newValue);

  return SourceEdit(valueSpan.start.offset, valueSpan.length, valueString);
}

/// Performs the string operation on [yaml] to achieve the effect of replacing
/// the value at [key] with [newValue] when reparsed, bearing in mind that this is a
/// block map.
SourceEdit _replaceInBlockMap(
    String yaml, YamlMap map, Object key, Object newValue, YamlStyle style) {
  final newIndentation = getMapIndentation(yaml, map) + style.indentationStep;
  final value = map.nodes[key];
  final keyNode = getKeyNode(map, key);
  var valueString = getBlockString(newValue, newIndentation);

  /// +2 accounts for the colon
  final start = keyNode.span.end.offset + 2;
  final end = getContentSensitiveEnd(value);

  return SourceEdit(start, end - start, valueString);
}

/// Performs the string operation on [yaml] to achieve the effect of removing
/// the [key] from the map, bearing in mind that this is a flow map.
SourceEdit _removeFromFlowMap(
    String yaml, YamlMap map, YamlNode keyNode, YamlNode valueNode) {
  var start = keyNode.span.start.offset;
  var end = valueNode.span.end.offset;

  if (deepEquals(keyNode, map.keys.first)) {
    start = yaml.lastIndexOf('{', start) + 1;

    if (deepEquals(keyNode, map.keys.last)) {
      end = yaml.indexOf('}', end);
    } else {
      end = yaml.indexOf(',', end) + 1;
    }
  } else {
    start = yaml.lastIndexOf(',', start);
  }

  return SourceEdit(start, end - start, '');
}

/// Performs the string operation on [yaml] to achieve the effect of removing
/// the [key] from the map, bearing in mind that this is a block map.
SourceEdit _removeFromBlockMap(
    String yaml, YamlMap map, YamlNode keyNode, YamlNode valueNode) {
  final keySpan = keyNode.span;
  final end = getContentSensitiveEnd(valueNode);

  if (map.length == 1) {
    final start = map.span.start.offset;

    return SourceEdit(start, end - start, '{}');
  }

  var start = yaml.lastIndexOf('\n', keySpan.start.offset);
  if (start == -1) start = 0;
  return SourceEdit(start, end - start, '');
}
