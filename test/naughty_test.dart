import 'dart:convert';

/// Quickly runs through all the strings in `test/blns/blns.json`
import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:yaml_edit/src/editor.dart';

void main() async {
  final packageUri = await Isolate.resolvePackageUri(
      Uri.parse('package:yaml_edit/yaml_edit.dart'));
  final blnsPath = packageUri.resolve('../test/blns/blns.json').path;
  final stringsFile = File(blnsPath);

  if (!stringsFile.existsSync()) return;

  final rawStrings = stringsFile.readAsStringSync();
  final strings = jsonDecode(rawStrings);

  for (var string in strings) {
    test('expect string $string', () {
      final doc = YamlEditor('');

      expect(() => doc.assign([], string), returnsNormally);
      final value = doc.parseAt([]).value;
      expect(value, isA<String>());
      expect(value, equals(string));
    });
  }
}
