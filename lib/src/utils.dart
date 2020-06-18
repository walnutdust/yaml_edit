import 'dart:collection';

import 'package:yaml/yaml.dart';
import 'package:yaml_edit/src/list_mutations.dart';

/// Returns `true` if [input] could be interpreted as a boolean by `package:yaml`,
/// `false` otherwise.
bool isPossibleBoolean(String input) {
  final trimmedInput = input.trim();

  switch (trimmedInput) {
    case 'true':
    case 'True':
    case 'TRUE':
    case 'false':
    case 'False':
    case 'FALSE':
      return true;
    default:
      return false;
  }
}

/// Returns `true` if [input] could be interpreted as a null value by `package:yaml`,
/// `false` otherwise.
bool isPossibleNull(String input) {
  final trimmedInput = input.trim();

  switch (trimmedInput) {
    case '':
    case 'null':
    case 'Null':
    case 'NULL':
    case '~':
      return true;
    default:
      return false;
  }
}

/// Returns a safe string by checking for strings that begin with > or |
/// as well as strings that can be interpreted as boolean
String getSafeString(Object value) {
  if (value is String) {
    if (value.startsWith('>') ||
        value.startsWith('|') ||
        isPossibleBoolean(value) ||
        isPossibleNull(value)) {
      return '\'$value\'';
    }
  }

  return value.toString();
}

/// Returns values as strings representing flow objects.
String getFlowString(Object value) => getSafeString(value);

/// Returns values as strings representing block objects.
///
/// We do a join('\n') rather than having it in the mapping to avoid
/// adding additional spaces when updating rather than adding elements.
String getBlockString(Object value,
    [int indentation = 0, int additionalIndentation = 2]) {
  if (value is List) {
    return '\n' + value.map((e) => ' ' * indentation + '- $e').join('\n');
  } else if (value is Map) {
    return '\n' +
        value.entries.map((entry) {
          final formattedKey = ' ' * indentation + '${entry.key}: ';
          var formattedValue;

          if (isCollection(entry.value)) {
            final newIndentation = indentation + additionalIndentation;
            formattedValue = getBlockString(entry.value, newIndentation);
          } else {
            formattedValue = getFlowString(entry.value);
          }

          return formattedKey + formattedValue;
        }).join('\n');
  }

  return getSafeString(value);
}

/// Returns the content sensitive ending offset of a node (i.e. where the last
/// meaningful content happens)
int getContentSensitiveEnd(YamlNode yamlNode) {
  if (yamlNode is YamlList) {
    if (yamlNode.style == CollectionStyle.FLOW) {
      return yamlNode.span.end.offset;
    } else {
      return getContentSensitiveEnd(yamlNode.nodes.last);
    }
  } else if (yamlNode is YamlMap) {
    if (yamlNode.style == CollectionStyle.FLOW) {
      return yamlNode.span.end.offset;
    } else {
      return getContentSensitiveEnd(yamlNode.nodes.values.last);
    }
  }

  return yamlNode.span.end.offset;
}

/// Checks if the item is a Map or a List
bool isCollection(Object item) => item is Map || item is List;

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

/// Gets the indentation level of the list. This is 0 if it is a flow list,
/// but returns the number of spaces before the hyphen of elements for
/// block lists.
///
/// Throws [UnsupportedError] if an empty block map is passed in.
int getListIndentation(String yaml, YamlList list) {
  if (list.style == CollectionStyle.FLOW) return 0;

  /// An empty block map doesn't really exist.
  if (list.isEmpty) {
    throw UnsupportedError('Unable to get indentation for empty block list');
  }

  final lastSpanOffset = list.nodes.last.span.start.offset;
  final lastNewLine = yaml.lastIndexOf('\n', lastSpanOffset);
  final lastHyphen = yaml.lastIndexOf('-', lastSpanOffset);

  if (lastNewLine == -1) return lastHyphen;

  return lastHyphen - lastNewLine - 1;
}

/// Returns the detected indentation level used for this YAML document, or defaults
/// to a value of `2` if no indentation level can be detected.
///
/// Indentation level is determined by the difference in indentation of the first
/// block-styled yaml collection in the second level as compared to the top-level
/// elements. In the case where there are multiple possible candidates, we choose
/// the candidate closest to the start of [yaml].
///
/// [yaml] must be a valid YAML document as defined by `package:yaml`.
int detectIndentation(String yaml) {
  final node = loadYamlNode(yaml);
  var children;

  if (node is YamlMap && node.style == CollectionStyle.BLOCK) {
    children = node.nodes.values;
  } else if (node is YamlList && node.style == CollectionStyle.BLOCK) {
    children = node.nodes;
  }

  if (children != null) {
    for (var child in children) {
      var indentation = 0;
      if (child is YamlList) {
        indentation = getListIndentation(yaml, child);
      } else if (child is YamlMap) {
        indentation = getMapIndentation(yaml, child);
      }

      if (indentation != 0) return indentation;
    }
  }

  return 2;
}
