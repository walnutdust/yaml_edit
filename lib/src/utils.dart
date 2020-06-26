import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

/// Determines if [string] is dangerous by checking if parsing the plain string can
/// return a result different from [string].
///
/// This function is also capable of detecting if non-printable characters are in
/// [string].
bool isDangerousString(String string) {
  try {
    if (loadYamlNode(string).value != string) {
      return true;
    }

    /// [string] should also not contain the `]` and `}` indicator characters.
    return string.contains(RegExp(r']|}'));
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

/// Checks if the item is a Map or a List
bool isCollection(Object item) => item is Map || item is List;

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
int detectIndentationSetting(String yaml) {
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

/// Returns if [value] is a [YamlList] or [YamlMap] with [CollectionStyle.FLOW].
bool isFlowYamlCollectionNode(Object value) {
  if (value is YamlList || value is YamlMap) {
    return (value as dynamic).style == CollectionStyle.FLOW;
  }

  return false;
}
