import 'package:test/test.dart';
import 'package:yaml_edit/src/utils.dart';

void main() {
  group('detectIndentation', () {
    test('returns 2 for empty strings', () {
      expect(detectIndentation(''), equals(2));
    });

    test('returns 2 for strings consisting only scalars', () {
      expect(detectIndentation('foo'), equals(2));
    });

    test('returns 2 if only top-level elements are present', () {
      expect(detectIndentation('''
- 1
- 2
- 3'''), equals(2));
    });

    test('detects the indentation used in nested list', () {
      expect(detectIndentation('''
- 1
- 2
- 
   - 3
   - 4'''), equals(3));
    });

    test('detects the indentation used in nested map', () {
      expect(detectIndentation('''
a: 1
b: 2
c:
   d: 4
   e: 5'''), equals(3));
    });

    test('detects the indentation used in nested map in list', () {
      expect(detectIndentation('''
- 1
- 2
- 
    d: 4
    e: 5'''), equals(4));
    });

    test('detects the indentation used in nested list in map', () {
      expect(detectIndentation('''
a: 1
b: 2
c:
  - 4
  - 5'''), equals(2));
    });
  });
}
