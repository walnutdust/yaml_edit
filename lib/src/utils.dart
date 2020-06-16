import 'package:yaml/src/equality.dart' as yaml_equality;
import 'package:yaml/yaml.dart';

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

/// Wraps [value] into a [YamlNode].
YamlNode yamlNodeFrom(Object value) {
  if (value is YamlNode) {
    return value;
  } else if (value is Map) {
    return YamlMap.wrap(value);
  } else if (value is List) {
    return YamlList.wrap(value);
  } else {
    return YamlScalar.wrap(value);
  }
}

/// Checks if [index] is [int], >=0, < [length]
bool isValidIndex(Object index, int length) {
  return index is int && index >= 0 && index < length;
}

/// Compares two [Object]s for deep equality, extending from `package:yaml`'s deep
/// equality notation to allow for comparison of non scalar map keys.
bool deepEquals(Object obj1, Object obj2) {
  if (obj1 is Map && obj2 is Map) {
    return mapDeepEquals(obj1, obj2);
  }

  return yaml_equality.deepEquals(obj1, obj2);
}

/// Compares two [Map]s for deep equality, extending from `package:yaml`'s deep
/// equality notation to allow for comparison of non scalar map keys.
bool mapDeepEquals(Map map1, Map map2) {
  if (map1.length != map2.length) return false;

  for (var key in map1.keys) {
    if (!containsKey(map2, key)) {
      return false;
    }

    /// Because two keys may be equal by deep equality but using one key on the
    /// other map might not get a hit.
    final key2 = getKey(map2, key);

    if (!deepEquals(map1[key], map2[key2])) {
      return false;
    }
  }

  return true;
}

/// Returns the [YamlNode] corresponding to the provided [key].
YamlNode getKeyNode(YamlMap map, Object key) {
  return (map.nodes.keys.firstWhere((node) => deepEquals(node, key))
      as YamlNode);
}

/// Returns the key in [map] that is equal to the provided [key] by the notion
/// of deep equality.
Object getKey(Map map, Object key) {
  return map.keys.firstWhere((k) => deepEquals(k, key));
}

/// Checks if [map] has any keys equal to the provided [key] by deep equality.
bool containsKey(Map map, Object key) {
  try {
    map.keys.firstWhere((node) => deepEquals(node, key));

    return true;
  } on StateError {
    return false;
  }
}
