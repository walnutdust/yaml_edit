import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

import 'wrap.dart';

/// Returns `true` if [input] could be interpreted as a boolean by `package:yaml`,
/// `false` otherwise.
///
/// See https://yaml.org/spec/1.2/spec.html#id2805019.
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
///
/// See https://yaml.org/spec/1.2/spec.html#id2805019.
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

/// Checks if [string] contains a YAML control character
///
/// TODO (walnut): Ensure that all the possibilities are covered.
bool containsControlCharacter(String string) {
  final controlCharacters = [
    '!',
    '&',
    '*',
    '-',
    '[',
    ']',
    '#',
    '|',
    '>',
    '@',
    '`',
    '"',
    '{',
    '}',
    ':'
  ];

  for (var controlChar in controlCharacters) {
    if (string.contains(controlChar)) return true;
  }

  return false;
}

/// Checks if [input] has leading or trailing whitespaces.
bool paddedByWhiteSpace(String input) {
  return input.trim().length - input.length != 0;
}

/// Returns a safe string by ensuring that if [value] was meant to be a string, it
/// will not be interpreted otherwise.
///
/// TODO (walnut): Look into  \0, special characters, and unicode characters.
String getSafeString(Object value) {
  if (value is YamlNode) {
    AssertionError(
        'YamlNodes should not be passed directly into getSafeString!');
  }

  if (value is Map || value is List) {
    AssertionError('Lists and Maps should not call getSafeString directly!');
  }

  if (value is String) {
    var result = value;

    /// If it contains a dangerous character we want to wrap the result with single
    /// quotes
    if (containsControlCharacter(value) ||
        isPossibleBoolean(value) ||
        isPossibleNull(value) ||
        paddedByWhiteSpace(value)) {
      /// But we need to escape the characters if they contain a single quote.
      if (value.contains('\'')) {
        result = value.replaceAll('\'', '\'\'');
      }

      return '\'$result\'';
    }

    return result;
  }

  return value.toString();
}

/// Returns [value] with the necessary formatting applied in a block context.
///
/// If [value] is a [YamlScalar], we try to respect its [style] parameter where
/// possible. Certain cases make this impossible (e.g. a plain string scalar that
/// starts with '>'), in which case we will produce [value] with default styling options.
String getFlowScalar(Object value) {
  if (value is Map || value is List) {
    AssertionError('Only scalars can be passed into getFlowScalar');
  }

  if (value is YamlScalar) {
    if (value.style == ScalarStyle.DOUBLE_QUOTED) {
      return '"${value.value.toString()}"';
    } else if (value.style == ScalarStyle.SINGLE_QUOTED) {
      return '\'${value.value.toString()}\'';
    }

    return getSafeString(value.value);
  }

  return getSafeString(value);
}

/// Returns [value] with the necessary formatting applied in a block context.
///
/// This only matters for [YamlScalar]s if they contain [ScalarStyle.FOLDED] or
/// [ScalarStyle.LITERAL] styling.
String getBlockScalar(Object value, int indentation,
    [int additionalIndentation = 2]) {
  if (value is Map || value is List) {
    AssertionError('Only scalars can be passed into getBlockScalar');
  }

  if (value is YamlScalar) {
    var result = '';

    if (value.style == ScalarStyle.FOLDED) {
      result += '>\n';
      result += ' ' * (indentation + additionalIndentation);
      return result + getSafeString(value.value);
    } else if (value.style == ScalarStyle.LITERAL) {
      result += '|\n';
      result += ' ' * (indentation + additionalIndentation);
      return result + getSafeString(value.value);
    }
  }

  /// The remainder of the possibilities are similar to how [getFlowScalar]
  /// treats [value].
  return getFlowScalar(value);
}

/// Returns [value] with the necessary formatting applied in a flow context.
///
/// If [value] is a [YamlNode], we try to respect its [style] parameter where
/// possible. Certain cases make this impossible (e.g. a plain string scalar that
/// starts with '>', a child having a block style parameters), in which case we
/// will produce [value] with default styling options.
String getFlowString(Object value) {
  if (value is List) {
    var list = value;

    if (value is YamlList) list = value.nodes;

    final safeValues = list.map((e) => getFlowString(e));
    return '[' + safeValues.join(', ') + ']';
  } else if (value is Map) {
    final safeEntries = value.entries.map((e) {
      final safeKey = getFlowString(e.key);
      final safeValue = getFlowString(e.value);
      return '$safeKey: $safeValue';
    });

    return '{' + safeEntries.join(', ') + '}';
  }

  return getFlowScalar(value);
}

/// Returns [value] with the necessary formatting applied in a block context.
///
/// If [value] is a [YamlNode], we respect its [style] parameter.
///
/// We do a join('\n') rather than having it in the mapping to avoid
/// adding additional spaces when updating rather than adding elements.
String getBlockString(Object value,
    [int indentation = 0, int additionalIndentation = 2]) {
  if (additionalIndentation < 1) {
    ArgumentError.value(
        additionalIndentation, 'additionalIndentation', 'must be positive!');
  }

  if (value is YamlNode && !isBlockNode(value)) {
    return getFlowString(value);
  }

  final newIndentation = indentation + additionalIndentation;

  if (value is List) {
    var safeValues;

    var children = value is YamlList ? value.nodes : value;

    safeValues = children.map((child) {
      final valueString = getBlockString(child, newIndentation);
      return ' ' * indentation + '- $valueString';
    });

    return '\n' + safeValues.join('\n');
  } else if (value is Map) {
    var children = value is YamlMap ? value.nodes : value;

    return '\n' +
        children.entries.map((entry) {
          final safeKey = getFlowString(entry.key);
          final formattedKey = ' ' * indentation + safeKey;
          final formattedValue = getBlockString(entry.value, newIndentation);

          return formattedKey + ': ' + formattedValue;
        }).join('\n');
  }

  return getBlockScalar(value, newIndentation);
}

/// Checks if [node] is a [YamlNode] with block styling.
///
/// [ScalarStyle.ANY] and [CollectionStyle.ANY] are considered to be block styling
/// by default for maximum flexibility.
bool isBlockNode(YamlNode node) {
  if (node is YamlScalar) {
    if (node.style == ScalarStyle.LITERAL ||
        node.style == ScalarStyle.FOLDED ||
        node.style == ScalarStyle.ANY) {
      return true;
    }
  }

  if (node is YamlList &&
      (node.style == CollectionStyle.BLOCK ||
          node.style == CollectionStyle.ANY)) return true;
  if (node is YamlMap &&
      (node.style == CollectionStyle.BLOCK ||
          node.style == CollectionStyle.ANY)) return true;

  return false;
}

/// Returns the content sensitive ending offset of [yamlNode] (i.e. where the last
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

/// Checks if [index] is [int], >=0, < [length]
bool isValidIndex(Object index, int length) {
  return index is int && index >= 0 && index < length;
}

/// Creates a [SourceSpan] from [sourceUrl] with no meaningful location
/// information.
///
/// Mainly used with [wrapAsYamlNode] to allow for a reasonable
/// implementation of [SourceSpan.message].
SourceSpan shellSpan(Object sourceUrl) {
  var shellSourceLocation = SourceLocation(0, sourceUrl: sourceUrl);
  return SourceSpanBase(shellSourceLocation, shellSourceLocation, '');
}
