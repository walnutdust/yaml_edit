import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/src/utils.dart';
import 'package:yaml_edit/src/wrap.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'test_utils.dart';

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

    test('detects the indentation used in nested map in list with complex keys',
        () {
      expect(detectIndentation('''
- 1
- 2
- 
    ? d
    : 4'''), equals(4));
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

  group('styling options', () {
    group('assign', () {
      test('flow map with style', () {
        final doc = YamlEditor("{YAML: YAML Ain't Markup Language}");
        doc.assign(['YAML'],
            wrapAsYamlNode('hi', scalarStyle: ScalarStyle.DOUBLE_QUOTED));

        expect(doc.toString(), equals('{YAML: "hi"}'));
        expectYamlBuilderValue(doc, {'YAML': 'hi'});
      });

      test('prevents block scalars in flow map', () {
        final doc = YamlEditor("{YAML: YAML Ain't Markup Language}");
        doc.assign(
            ['YAML'], wrapAsYamlNode('test', scalarStyle: ScalarStyle.FOLDED));

        expect(doc.toString(), equals('{YAML: test}'));
        expectYamlBuilderValue(doc, {'YAML': 'test'});
      });

      test('wraps string in double-quotes if it contains dangerous characters',
          () {
        final doc = YamlEditor("{YAML: YAML Ain't Markup Language}");
        doc.assign(
            ['YAML'], wrapAsYamlNode('> test', scalarStyle: ScalarStyle.PLAIN));

        expect(doc.toString(), equals('{YAML: "> test"}'));
        expectYamlBuilderValue(doc, {'YAML': '> test'});
      });

      test('list in map', () {
        final doc = YamlEditor('''YAML: YAML Ain't Markup Language''');
        doc.assign(['YAML'],
            wrapAsYamlNode([1, 2, 3], collectionStyle: CollectionStyle.FLOW));

        expect(doc.toString(), equals('YAML: [1, 2, 3]'));
        expectYamlBuilderValue(doc, {
          'YAML': [1, 2, 3]
        });
      });

      test('nested map', () {
        final doc = YamlEditor('''YAML: YAML Ain't Markup Language''');
        doc.assign(
            ['YAML'],
            wrapAsYamlNode({'YAML': "YAML Ain't Markup Language"},
                collectionStyle: CollectionStyle.FLOW));

        expect(
            doc.toString(), equals("YAML: {YAML: YAML Ain't Markup Language}"));
        expectYamlBuilderValue(doc, {
          'YAML': {'YAML': "YAML Ain't Markup Language"}
        });
      });

      test('nested list', () {
        final doc = YamlEditor('- 0');
        doc.assign(
            [0],
            wrapAsYamlNode([
              1,
              2,
              wrapAsYamlNode([3, 4], collectionStyle: CollectionStyle.FLOW),
              5
            ]));

        expect(doc.toString(), equals('''
- 
  - 1
  - 2
  - [3, 4]
  - 5'''));
        expectYamlBuilderValue(doc, [
          [
            1,
            2,
            [3, 4],
            5
          ]
        ]);
      });

      test('different scalars in block list!', () {
        final doc = YamlEditor('- 0');
        doc.assign(
            [0],
            wrapAsYamlNode([
              wrapAsYamlNode('plain string', scalarStyle: ScalarStyle.PLAIN),
              wrapAsYamlNode('folded string', scalarStyle: ScalarStyle.FOLDED),
              wrapAsYamlNode('single-quoted string',
                  scalarStyle: ScalarStyle.SINGLE_QUOTED),
              wrapAsYamlNode('literal string',
                  scalarStyle: ScalarStyle.LITERAL),
              wrapAsYamlNode('double-quoted string',
                  scalarStyle: ScalarStyle.DOUBLE_QUOTED),
            ]));

        expect(doc.toString(), equals('''
- 
  - plain string
  - >
        folded string
  - 'single-quoted string'
  - |
        literal string
  - "double-quoted string"'''));
        expectYamlBuilderValue(doc, [
          [
            'plain string',
            'folded string\n',
            'single-quoted string',
            'literal string\n',
            'double-quoted string',
          ]
        ]);
      });

      test('different scalars in block map!', () {
        final doc = YamlEditor('strings: strings');
        doc.assign(
            ['strings'],
            wrapAsYamlNode({
              'plain': wrapAsYamlNode('string', scalarStyle: ScalarStyle.PLAIN),
              'folded':
                  wrapAsYamlNode('string', scalarStyle: ScalarStyle.FOLDED),
              'single-quoted': wrapAsYamlNode('string',
                  scalarStyle: ScalarStyle.SINGLE_QUOTED),
              'literal':
                  wrapAsYamlNode('string', scalarStyle: ScalarStyle.LITERAL),
              'double-quoted': wrapAsYamlNode('string',
                  scalarStyle: ScalarStyle.DOUBLE_QUOTED),
            }));

        expect(doc.toString(), equals('''
strings: 
  plain: string
  folded: >
        string
  single-quoted: 'string'
  literal: |
        string
  double-quoted: "string"'''));
        expectYamlBuilderValue(doc, {
          'strings': {
            'plain': 'string',
            'folded': 'string\n',
            'single-quoted': 'string',
            'literal': 'string\n',
            'double-quoted': 'string',
          }
        });
      });

      test('different scalars in flow list!', () {
        final doc = YamlEditor('[0]');
        doc.assign(
            [0],
            wrapAsYamlNode([
              wrapAsYamlNode('plain string', scalarStyle: ScalarStyle.PLAIN),
              wrapAsYamlNode('folded string', scalarStyle: ScalarStyle.FOLDED),
              wrapAsYamlNode('single-quoted string',
                  scalarStyle: ScalarStyle.SINGLE_QUOTED),
              wrapAsYamlNode('literal string',
                  scalarStyle: ScalarStyle.LITERAL),
              wrapAsYamlNode('double-quoted string',
                  scalarStyle: ScalarStyle.DOUBLE_QUOTED),
            ]));

        expect(
            doc.toString(),
            equals(
                '[[plain string, folded string, \'single-quoted string\', literal string, "double-quoted string"]]'));
        expectYamlBuilderValue(doc, [
          [
            'plain string',
            'folded string',
            'single-quoted string',
            'literal string',
            'double-quoted string',
          ]
        ]);
      });

      test('wraps non-printable strings in double-quotes', () {
        final doc = YamlEditor('[0]');
        doc.assign([0], '\x00');
        expect(doc.toString(), equals('["\\0"]'));
        expectYamlBuilderValue(doc, ['\x00']);
      });
    });
  });
}
