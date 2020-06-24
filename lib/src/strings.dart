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
  return result + _tryGetPlainString(string).replaceAll('\n', '\n\n');
}

/// Generates a YAML-safe literal string.
///
/// It is important that we ensure that [string] is free of unprintable characters
/// by calling [assertValidScalar] before invoking this function.
String _getLiteralString(String string, int indentation) {
  final plainString = _tryGetPlainString(string);
  final result = '|\n$plainString';
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
    var safeValues;

    var children = value is YamlList ? value.nodes : value;

    safeValues = children.map((child) {
      final valueString = getBlockString(child, newIndentation);
      return ' ' * indentation + '- $valueString';
    });

    return safeValues.join('\n');
  } else if (value is Map) {
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
