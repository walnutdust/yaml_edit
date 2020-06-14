import 'package:test/test.dart';
import 'package:yaml_edit/src/style.dart';

void main() {
  group('YamlStyle', () {
    test('Initializes correctly', () {
      final style = YamlStyle(indentationStep: 3, enforceFlow: true);

      expect(style.indentationStep, equals(3));
      expect(style.enforceFlow, equals(true));
    });

    test('withOpts works as expected', () {
      final style = YamlStyle(indentationStep: 3, enforceFlow: true);
      final style2 = style.withOpts(indentStep: 4);

      expect(style.indentationStep, equals(3));
      expect(style.enforceFlow, equals(true));

      expect(style2.indentationStep, equals(4));
      expect(style2.enforceFlow, equals(true));
    });
  });
}
