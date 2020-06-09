import 'dart:convert';

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
  bool operator ==(other) {
    return offset == other.offset &&
        length == other.length &&
        replacement == other.replacement;
  }

  /// Constructs a SourceEdit from a json-encoded String.
  factory SourceEdit.fromJson(String json) {
    var jsonEdit = jsonDecode(json);

    if (jsonEdit is Map) {
      int offset;
      if (jsonEdit.containsKey('offset') &&
          jsonEdit.containsKey('length') &&
          jsonEdit.containsKey('replacement')) {
        offset = (jsonEdit['offset'] as int);
      }
      int length;
      if (jsonEdit.containsKey('length')) {
        length = (jsonEdit['length'] as int);
      }
      String replacement;
      if (jsonEdit.containsKey('replacement')) {
        replacement = (jsonEdit['replacement'] as String);
      }
      return SourceEdit(offset, length, replacement);
    } else {
      throw Exception('Invalid JSON passed to SourceEdit');
    }
  }

  /// Encodes this object in JSON.
  String toJSON() {
    var map = {'offset': offset, 'length': length, 'replacement': replacement};

    return jsonEncode(map);
  }

  @override
  String toString() => toJSON();

  /// Applies a series of [SourceEdit]s to an original string, and return the final output
  static String apply(String original, List<SourceEdit> edits) {
    var current = original;
    for (var edit in edits) {
      current = current.replaceRange(
          edit.offset, edit.offset + edit.length, edit.replacement);
    }

    return current;
  }
}
