import 'dart:convert' show jsonEncode, jsonDecode;
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
  /// import 'dart:convert' show jsonEncode;
  ///
  /// final editMap = {
  ///   'offset': 1,
  ///   'length': 2,
  ///   'replacement': 'replacement string'
  /// };
  ///
  /// final jsonMap = jsonEncode(editMap);
  /// final sourceEdit = SourceEdit.fromJson(jsonMap);
  /// ```
  factory SourceEdit.fromJson(Object json) {
    var jsonEdit = jsonDecode(json);

    if (jsonEdit is Map) {
      final offset = jsonEdit['offset'];
      final length = jsonEdit['length'];
      final replacement = jsonEdit['replacement'];

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
  dynamic toJson() {
    var map = {'offset': offset, 'length': length, 'replacement': replacement};

    return jsonEncode(map);
  }

  @override
  String toString() => 'SourceEdit($offset, $length, "$replacement")';

  /// Applies a series of [SourceEdit]s to an original string, and return the final output.
  ///
  /// [edits] should be in order i.e. the first [SourceEdit] in [edits] should be the first
  /// edit applied to [original].
  static String apply(String original, Iterable<SourceEdit> edits) {
    var current = original;
    for (var edit in edits) {
      current = SourceEdit.applyOne(current, edit);
    }

    return current;
  }

  /// Applies one [SourceEdit]s to an original string, and return the final output.
  static String applyOne(String original, SourceEdit edit) {
    return original.replaceRange(
        edit.offset, edit.offset + edit.length, edit.replacement);
  }
}
