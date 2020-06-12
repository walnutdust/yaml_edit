import 'package:quiver_hashcode/hashcode.dart' show hash3;

/// A class representing a change on a String, intended to be compatible with
/// `package:analysis_server`'s [SourceEdit].
class SourceEdit {
  /// The offset from the start of the string where the modification begins.
  final int offset;

  /// The length of the substring to be replaced.
  final int length;

  /// The replacement string to be used.
  final String replacement;

  SourceEdit(this.offset, this.length, this.replacement);

  @override
  bool operator ==(Object other) {
    if (other is SourceEdit) {
      return offset == other.offset &&
          length == other.length &&
          replacement == other.replacement;
    }

    return false;
  }

  @override
  int get hashCode => hash3(offset, length, replacement);

  /// Constructs a SourceEdit from Json.
  ///
  /// ```dart
  /// final edit = {
  ///   'offset': 1,
  ///   'length': 2,
  ///   'replacement': 'replacement string'
  /// };
  ///
  /// final sourceEdit = SourceEdit.fromJson(edit);
  /// ```
  factory SourceEdit.fromJson(Map<String, dynamic> json) {
    if (json is Map) {
      final offset = json['offset'];
      final length = json['length'];
      final replacement = json['replacement'];

      if (offset is int && length is int && replacement is String) {
        return SourceEdit(offset, length, replacement);
      }
    }
    throw FormatException('Invalid JSON passed to SourceEdit');
  }

  /// Encodes this object as JSON-compatible structure.
  ///
  /// ```dart
  /// import 'dart:convert' show jsonEncode;
  ///
  /// final edit = SourceEdit(offset, length, 'replacement string');
  /// final jsonString = jsonEncode(edit.toJson());
  /// print(jsonString);
  /// ```
  Map<String, dynamic> toJson() {
    return {'offset': offset, 'length': length, 'replacement': replacement};
  }

  @override
  String toString() => 'SourceEdit($offset, $length, "$replacement")';

  /// Applies a series of [SourceEdit]s to an original string, and return the final output.
  ///
  /// [edits] should be in order i.e. the first [SourceEdit] in [edits] should be the first
  /// edit applied to [original].
  static String applyAll(String original, Iterable<SourceEdit> edits) {
    var current = original;
    for (var edit in edits) {
      current = edit.apply(current);
    }

    return current;
  }

  /// Applies one [SourceEdit]s to an original string, and return the final output.
  String apply(String original) {
    return original.replaceRange(offset, offset + length, replacement);
  }
}
