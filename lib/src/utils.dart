import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

/// Determines if [string] is dangerous by checking if parsing the plain string can
/// return a result different from [string].
///
/// This function is also capable of detecting if non-printable characters are in
/// [string].
bool isDangerousString(String string) {
  try {
    return loadYamlNode(string).value != string;
  } catch (YamlException) {
    return true;
  }
}

/// Asserts that [value] is a valid scalar according to YAML.
///
/// A valid scalar is a number, String, boolean, or null.
void assertValidScalar(Object value) {
  if (value is num || value is String || value is bool || value == null) {
    return;
  }

  throw ArgumentError.value(value, 'value', 'Not a valid scalar type!');
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

/// Gets the indentation level of the map. This is 0 if it is a flow map,
/// but returns the number of spaces before the keys for block maps.
int getMapIndentation(String yaml, YamlMap map) {
  if (map.style == CollectionStyle.FLOW) return 0;

  /// An empty block map doesn't really exist.
  if (map.isEmpty) {
    throw UnsupportedError('Unable to get indentation for empty block map');
  }

  /// Use the number of spaces between the last key and the newline as indentation.
  final lastKey = map.nodes.keys.last as YamlNode;
  final lastSpanOffset = lastKey.span.start.offset;
  final lastNewLine = yaml.lastIndexOf('\n', lastSpanOffset);
  final lastQuestionMark = yaml.lastIndexOf('?', lastSpanOffset);

  if (lastQuestionMark == -1) {
    if (lastNewLine == -1) return lastSpanOffset;
    return lastSpanOffset - lastNewLine - 1;
  }

  if (lastNewLine == -1) return lastQuestionMark;
  return lastQuestionMark - lastNewLine - 1;
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

/// List of unprintable characters.
///
/// See 5.7 Escape Characters https://yaml.org/spec/1.2/spec.html#id2776092
final Map<int, String> unprintableCharCodes = {
  0: '\\0', //  Escaped ASCII null (#x0) character.
  7: '\\a', //  Escaped ASCII bell (#x7) character.
  8: '\\b', //  Escaped ASCII backspace (#x8) character.
  11: '\\v', // 	Escaped ASCII vertical tab (#xB) character.
  12: '\\f', //  Escaped ASCII form feed (#xC) character.
  13: '\\r', //  Escaped ASCII carriage return (#xD) character. Line Break.
  27: '\\e', //  Escaped ASCII escape (#x1B) character.
  133: '\\N', //  Escaped Unicode next line (#x85) character.
  160: '\\_', //  Escaped Unicode non-breaking space (#xA0) character.
  8232: '\\L', //  Escaped Unicode line separator (#x2028) character.
  8233: '\\P', //  Escaped Unicode paragraph separator (#x2029) character.
};

/// List of escape characters. In particular, \x32 is not included because it
/// can be processed normally.
///
/// See 5.7 Escape Characters https://yaml.org/spec/1.2/spec.html#id2776092
final Map<int, String> doubleQuoteEscapeChars = {
  ...unprintableCharCodes,
  9: '\\t', //  Escaped ASCII horizontal tab (#x9) character. Printable
  10: '\\n', //  Escaped ASCII line feed (#xA) character. Line Break.
  34: '\\"', //  Escaped ASCII double quote (#x22).
  47: '\\/', //  Escaped ASCII slash (#x2F), for JSON compatibility.
  72: '\\\\', //  Escaped ASCII back slash (#x5C).
};
