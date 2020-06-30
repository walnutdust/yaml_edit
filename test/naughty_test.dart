import 'package:test/test.dart';
import 'package:yaml_edit/src/editor.dart';

import './blns/blns.dart';

void main() async {
  for (var string in naughtyStrings) {
    test('expect string $string', () {
      final doc = YamlEditor('');

      expect(() => doc.assign([], string), returnsNormally);
      final value = doc.parseAt([]).value;
      expect(value, isA<String>());
      expect(value, equals(string));
    });
  }
}
