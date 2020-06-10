import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:test/test.dart';
import 'package:yaml_edit/yaml_edit.dart';

void main() {
  group('SourceEdit', () {
    group('fromJson', () {
      test('converts from jsonEncode', () {
        final sourceEditMap = {
          'offset': 1,
          'length': 2,
          'replacement': 'replacement string'
        };
        final sourceEditJson = jsonEncode(sourceEditMap);
        final sourceEdit = SourceEdit.fromJson(sourceEditJson);

        expect(sourceEdit.offset, 1);
        expect(sourceEdit.length, 2);
        expect(sourceEdit.replacement, 'replacement string');
      });

      test('throws formatException if offset is non-int', () {
        final sourceEditJson = jsonEncode(
            {'offset': '1', 'length': 2, 'replacement': 'replacement string'});

        expect(
            () => SourceEdit.fromJson(sourceEditJson), throwsFormatException);
      });

      test('throws formatException if length is non-int', () {
        final sourceEditJson = jsonEncode(
            {'offset': 1, 'length': '2', 'replacement': 'replacement string'});

        expect(
            () => SourceEdit.fromJson(sourceEditJson), throwsFormatException);
      });

      test('throws formatException if replacement is non-string', () {
        final sourceEditJson =
            jsonEncode({'offset': 1, 'length': 2, 'replacement': 3});

        expect(
            () => SourceEdit.fromJson(sourceEditJson), throwsFormatException);
      });

      test('throws formatException if a field is not present', () {
        final sourceEditJson = jsonEncode({'offset': 1, 'length': 2});

        expect(
            () => SourceEdit.fromJson(sourceEditJson), throwsFormatException);
      });
    });

    group('toJson', () {
      test('is compatible with jsonEncode', () {
        final sourceEdit = SourceEdit(1, 2, 'replacement string');
        final sourceEditJson = sourceEdit.toJson();

        expect(
            sourceEditJson,
            jsonEncode({
              'offset': 1,
              'length': 2,
              'replacement': 'replacement string'
            }));

        expect(
            jsonDecode(sourceEditJson),
            equals({
              'offset': 1,
              'length': 2,
              'replacement': 'replacement string'
            }));
      });

      test('is compatible with fromJson', () {
        final sourceEdit = SourceEdit(1, 2, 'replacement string');
        final sourceEditJson = sourceEdit.toJson();
        final newSourceEdit = SourceEdit.fromJson(sourceEditJson);

        expect(newSourceEdit.offset, 1);
        expect(newSourceEdit.length, 2);
        expect(newSourceEdit.replacement, 'replacement string');
      });
    });

    group('apply', () {
      test('returns original string when empty list is passed in', () {
        final original = 'YAML: YAML';
        final result = SourceEdit.apply(original, []);

        expect(result, original);
      });
      test('works with list of one SourceEdit', () {
        final original = 'YAML: YAML';
        final sourceEdits = [SourceEdit(6, 4, 'YAML Ain\'t Markup Language')];

        final result = SourceEdit.apply(original, sourceEdits);

        expect(result, "YAML: YAML Ain't Markup Language");
      });
      test('works with list of multiple SourceEdits', () {
        final original = 'YAML: YAML';
        final sourceEdits = [
          SourceEdit(6, 4, "YAML Ain't Markup Language"),
          SourceEdit(6, 4, "YAML Ain't Markup Language"),
          SourceEdit(0, 4, "YAML Ain't Markup Language")
        ];

        final result = SourceEdit.apply(original, sourceEdits);

        expect(result,
            "YAML Ain't Markup Language: YAML Ain't Markup Language Ain't Markup Language");
      });
    });
  });

  group('YamlEditBuilder records edits', () {
    test('returns empty list at start', () {
      final yamlEditBuilder = YamlEditor('YAML: YAML');

      expect(yamlEditBuilder.edits, []);
    });

    test('after one change', () {
      final yamlEditBuilder = YamlEditor('YAML: YAML');
      yamlEditBuilder.setIn(['YAML'], "YAML Ain't Markup Language");

      expect(yamlEditBuilder.edits,
          [SourceEdit(6, 4, "YAML Ain't Markup Language")]);
    });

    test('after multiple changes', () {
      final yamlEditBuilder = YamlEditor('YAML: YAML');
      yamlEditBuilder.setIn(['YAML'], "YAML Ain't Markup Language");
      yamlEditBuilder.setIn(['XML'], 'Extensible Markup Language');
      yamlEditBuilder.removeIn(['YAML']);

      expect(yamlEditBuilder.edits, [
        SourceEdit(6, 4, "YAML Ain't Markup Language"),
        SourceEdit(32, 0, '\nXML: Extensible Markup Language\n'),
        SourceEdit(0, 32, '')
      ]);
    });
  });
}
