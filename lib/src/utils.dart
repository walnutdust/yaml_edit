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
String getFlowString(Object value) {
  return getSafeString(value);
}

/// Returns values as strings representing block objects.
///
/// We do a join('\n') rather than having it in the mapping to avoid
/// adding additional spaces when updating rather than adding elements.
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

  return getSafeString(value);
}

/// Returns the content sensitive ending offset of a node (i.e. where the last
/// meaningful content happens)
int getContentSensitiveEnd(YamlNode yamlNode) {
  if (yamlNode is YamlList) {
    if (yamlNode.style == CollectionStyle.FLOW) {
      return getContentSensitiveEnd(yamlNode.nodes.last) + 1;
    } else {
      return getContentSensitiveEnd(yamlNode.nodes.last);
    }
  } else if (yamlNode is YamlMap) {
    if (yamlNode.style == CollectionStyle.FLOW) {
      return getContentSensitiveEnd(yamlNode.nodes.values.last) + 1;
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
