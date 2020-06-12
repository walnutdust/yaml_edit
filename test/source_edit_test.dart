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
        final sourceEdit = SourceEdit.fromJson(sourceEditMap);

        expect(sourceEdit.offset, 1);
        expect(sourceEdit.length, 2);
        expect(sourceEdit.replacement, 'replacement string');
      });

      test('throws formatException if offset is non-int', () {
        final sourceEditJson = {
          'offset': '1',
          'length': 2,
          'replacement': 'replacement string'
        };

        expect(
            () => SourceEdit.fromJson(sourceEditJson), throwsFormatException);
      });

      test('throws formatException if length is non-int', () {
        final sourceEditJson = {
          'offset': 1,
          'length': '2',
          'replacement': 'replacement string'
        };

        expect(
            () => SourceEdit.fromJson(sourceEditJson), throwsFormatException);
      });

      test('throws formatException if replacement is non-string', () {
        final sourceEditJson = {'offset': 1, 'length': 2, 'replacement': 3};

        expect(
            () => SourceEdit.fromJson(sourceEditJson), throwsFormatException);
      });

      test('throws formatException if a field is not present', () {
        final sourceEditJson = {'offset': 1, 'length': 2};

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

    group('applyAll', () {
      test('returns original string when empty list is passed in', () {
        final original = 'YAML: YAML';
        final result = SourceEdit.applyAll(original, []);

        expect(result, original);
      });
      test('works with list of one SourceEdit', () {
        final original = 'YAML: YAML';
        final sourceEdits = [SourceEdit(6, 4, 'YAML Ain\'t Markup Language')];

        final result = SourceEdit.applyAll(original, sourceEdits);

        expect(result, "YAML: YAML Ain't Markup Language");
      });
      test('works with list of multiple SourceEdits', () {
        final original = 'YAML: YAML';
        final sourceEdits = [
          SourceEdit(6, 4, "YAML Ain't Markup Language"),
          SourceEdit(6, 4, "YAML Ain't Markup Language"),
          SourceEdit(0, 4, "YAML Ain't Markup Language")
        ];

        final result = SourceEdit.applyAll(original, sourceEdits);

        expect(result,
            "YAML Ain't Markup Language: YAML Ain't Markup Language Ain't Markup Language");
      });
    });
  });
}
