import 'package:test/test.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'problem_strings.dart';

void main() {
  for (var string in problemStrings) {
    test('expect string $string', () {
      final doc = YamlEditor('');

      expect(() => doc.update([], string), returnsNormally);
      final value = doc.parseAt([]).value;
      expect(value, isA<String>());
      expect(value, equals(string));
    });
  }
}
