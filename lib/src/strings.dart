import 'package:yaml/yaml.dart';
import 'utils.dart';

/// Given [value], tries to format it into a plain string recognizable by YAML. If
/// it fails, it defaults to returning a double-quoted string.
///
/// Not all values can be formatted into a plain string. If the string contains an
/// escape sequence, it can only be detected when in a double-quoted sequence. Plain
/// strings may also be misinterpreted by the YAML parser (e.g. ' null').
String _tryGetPlainString(Object value) {
  if (value is YamlNode) {
    AssertionError(
        'YamlNodes should not be passed directly into getSafeString!');
  }

  assertValidScalar(value);

  if (value is String) {
    /// If it contains a dangerous character we want to wrap the result with double
    /// quotes because the double quoted style allows for arbitrary strings with "\"
    /// escape sequences.
    ///
    /// See 7.3.1 Double-Quoted Style https://yaml.org/spec/1.2/spec.html#id2787109
    if (isDangerousString(value)) {
      return _getDoubleQuotedString(value);
    }

    return value;
  }

  return value.toString();
}

/// Checks if [string] has unprintable characters according to [unprintableCharCodes].
bool hasUnprintableCharacters(String string) {
  final codeUnits = string.codeUnits;

  for (var key in unprintableCharCodes.keys) {
    if (codeUnits.contains(key)) return true;
  }

  return false;
}

/// Generates a YAML-safe double-quoted string based on [string], escaping the
/// list of characters as defined by the YAML 1.2 spec.
///
/// See 5.7 Escaped Characters https://yaml.org/spec/1.2/spec.html#id2776092
String _getDoubleQuotedString(String string) {
  final buffer = StringBuffer();
  for (var codeUnit in string.codeUnits) {
    if (doubleQuoteEscapeChars[codeUnit] != null) {
      buffer.write(doubleQuoteEscapeChars[codeUnit]);
    } else {
      buffer.writeCharCode(codeUnit);
    }
  }

  return '"$buffer"';
}

/// Generates a YAML-safe single-quoted string. Automatically escapes single-quotes.
///
/// It is important that we ensure that [string] is free of unprintable characters
/// by calling [assertValidScalar] before invoking this function.
String _getSingleQuotedString(String string) {
  final result = string.replaceAll('\'', '\'\'');
  return '\'$result\'';
}

/// Generates a YAML-safe folded string.
///
/// It is important that we ensure that [string] is free of unprintable characters
/// by calling [assertValidScalar] before invoking this function.
String _getFoldedString(String string, int indentation) {
  var result = '>\n';
  result += ' ' * indentation;
  return result + string.replaceAll('\n', '\n\n' + ' ' * indentation);
}

/// Generates a YAML-safe literal string.
///
/// It is important that we ensure that [string] is free of unprintable characters
/// by calling [assertValidScalar] before invoking this function.
String _getLiteralString(String string, int indentation) {
  final result = '|\n$string';
  return result.replaceAll('\n', '\n' + ' ' * indentation);
}

/// Returns [value] with the necessary formatting applied in a flow context
/// if possible.
///
/// If [value] is a [YamlScalar], we try to respect its [style] parameter where
/// possible. Certain cases make this impossible (e.g. a plain string scalar that
/// starts with '>'), in which case we will produce [value] with default styling
/// options.
String getFlowScalar(Object value) {
  if (value is YamlScalar) {
    assertValidScalar(value.value);

    if (value.value is String) {
      if (hasUnprintableCharacters(value.value) ||
          value.style == ScalarStyle.DOUBLE_QUOTED) {
        return _getDoubleQuotedString(value.value);
      }

      if (value.style == ScalarStyle.SINGLE_QUOTED) {
        return _getSingleQuotedString(value.value);
      }
    }

    return _tryGetPlainString(value.value);
  }

  assertValidScalar(value);
  return _tryGetPlainString(value);
}

/// Returns [value] with the necessary formatting applied in a block context
/// if possible.
///
/// If [value] is a [YamlScalar], we try to respect its [style] parameter where
/// possible. Certain cases make this impossible (e.g. a folded string scalar
/// 'null'), in which case we will produce [value] with default styling
/// options.
String getBlockScalar(Object value, int indentation) {
  if (value is YamlScalar) {
    assertValidScalar(value.value);

    if (value.value is String) {
      if (hasUnprintableCharacters(value.value)) {
        return _getDoubleQuotedString(value.value);
      }

      if (value.style == ScalarStyle.SINGLE_QUOTED) {
        return _getSingleQuotedString(value.value);
      }

      if (value.style == ScalarStyle.FOLDED) {
        return _getFoldedString(value.value, indentation);
      }

      if (value.style == ScalarStyle.LITERAL) {
        return _getLiteralString(value.value, indentation);
      }
    }

    return _tryGetPlainString(value.value);
  }

  assertValidScalar(value);

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
    if (value.isEmpty) return ' ' * indentation + '[]';

    var safeValues;

    var children = value is YamlList ? value.nodes : value;

    safeValues = children.map((child) {
      final valueString = getBlockString(child, newIndentation);
      return ' ' * indentation + '- $valueString';
    });

    return safeValues.join('\n');
  } else if (value is Map) {
    if (value.isEmpty) return ' ' * indentation + '{}';

    var children = value is YamlMap ? value.nodes : value;

    return children.entries.map((entry) {
      final safeKey = getFlowString(entry.key);
      final formattedKey = ' ' * indentation + safeKey;
      final formattedValue = getBlockString(entry.value, newIndentation);

      return formattedKey + ': ' + formattedValue;
    }).join('\n');
  }

  return getBlockScalar(value, newIndentation);
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
  92: '\\\\', //  Escaped ASCII back slash (#x5C).
};
