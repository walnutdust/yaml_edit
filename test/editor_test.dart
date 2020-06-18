import 'package:test/test.dart';
import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

import 'test_utils.dart';

void main() {
  group('preserves original yaml: ', () {
    test('number', expectLoadPreservesYAML('2'));
    test('number with leading and trailing lines', expectLoadPreservesYAML('''
      
      2
      
      '''));
    test('octal numbers', expectLoadPreservesYAML('0o14'));
    test('negative numbers', expectLoadPreservesYAML('-345'));
    test('hexadecimal numbers', expectLoadPreservesYAML('0x123abc'));
    test('floating point numbers', expectLoadPreservesYAML('345.678'));
    test('exponential numbers', expectLoadPreservesYAML('12.3015e+02'));
    test('string', expectLoadPreservesYAML('a string'));
    test('string with control characters',
        expectLoadPreservesYAML('a string \\n'));
    test('string with control characters',
        expectLoadPreservesYAML('a string \n\r'));
    test('string with hex escapes',
        expectLoadPreservesYAML('\\x0d\\x0a is \\r\\n'));
    test('flow map', expectLoadPreservesYAML('{a: 2}'));
    test('flow list', expectLoadPreservesYAML('[1, 2]'));
    test('flow list with different types of elements',
        expectLoadPreservesYAML('[1, a]'));
    test('flow list with weird spaces',
        expectLoadPreservesYAML('[ 1 ,      2]'));
    test('multiline string', expectLoadPreservesYAML('''
      Mark set a major league
      home run record in 1998.'''));
    test('tilde', expectLoadPreservesYAML('~'));
    test('false', expectLoadPreservesYAML('false'));

    test('block map', expectLoadPreservesYAML('''a: 
    b: 1
    '''));
    test('block list', expectLoadPreservesYAML('''a: 
    - 1
    '''));
    test('complicated example', () {
      expectLoadPreservesYAML('''verb: RecommendCafes
map:
  a: 
    b: 1
recipe:
  - verb: Score
    outputs: ["DishOffering[]/Scored", "Suggestions"]
    name: Hotpot
  - verb: Rate
    inputs: Dish
    ''');
    });
  });

  group('parseAt', () {
    test('throws ArgumentError if key does not exist', () {
      final doc = YamlEditor('{a: 4}');
      final path = ['b'];

      expect(() => doc.parseAt(path), throwsArgumentError);
    });

    test('throws ArgumentError if path tries to go deeper into a scalar', () {
      final doc = YamlEditor('{a: 4}');
      final path = ['a', 'b'];

      expect(() => doc.parseAt(path), throwsArgumentError);
    });

    test('throws ArgumentError if index is out of bounds', () {
      final doc = YamlEditor('[0,1]');
      final path = [2];

      expect(() => doc.parseAt(path), throwsArgumentError);
    });

    test('throws ArgumentError if index is not an integer', () {
      final doc = YamlEditor('[0,1]');
      final path = ['2'];

      expect(() => doc.parseAt(path), throwsArgumentError);
    });

    group('returns a YamlNode', () {
      test('with the correct type', () {
        final doc = YamlEditor("YAML: YAML Ain't Markup Language");
        final expectedYamlScalar = doc.parseAt(['YAML']);

        expect(expectedYamlScalar, isA<YamlScalar>());
      });

      test('with the correct value', () {
        final doc = YamlEditor("YAML: YAML Ain't Markup Language");

        expect(doc.parseAt(['YAML']).value, "YAML Ain't Markup Language");
      });

      test('with the correct value in nested collection', () {
        final doc = YamlEditor('''
a: 1
b: 
  d: 4
  e: [5, 6, 7]
c: 3
''');

        expect(doc.parseAt(['b', 'e', 2]).value, 7);
      });

      test('with the correct type (2)', () {
        final doc = YamlEditor("YAML: YAML Ain't Markup Language");
        final expectedYamlMap = doc.parseAt([]);

        expect(expectedYamlMap is YamlMap, equals(true));
      });

      test('that is immutable', () {
        final doc = YamlEditor("YAML: YAML Ain't Markup Language");
        final expectedYamlMap = doc.parseAt([]);

        expect(() => (expectedYamlMap as YamlMap)['YAML'] = 'test',
            throwsUnsupportedError);
      });

      test('that has immutable children', () {
        final doc = YamlEditor("YAML: ['Y', 'A', 'M', 'L']");
        final expectedYamlMap = doc.parseAt([]);

        expect(() => (expectedYamlMap as YamlMap)['YAML'][0] = 'X',
            throwsUnsupportedError);
      });
    });

    group('orElse provides a default value', () {
      test('simple example with null return ', () {
        final doc = YamlEditor('{a: {d: 4}, c: ~}');
        var result = doc.parseAt(['b'], orElse: null);

        expect(result, isA<YamlScalar>());
        expect(result.value, equals(null));
      });

      test('simple example with map return', () {
        final doc = YamlEditor('{a: {d: 4}, c: ~}');
        var result = doc.parseAt(['b'], orElse: {'a': 42});

        expect(result, isA<YamlMap>());
        expect(result.value, equals({'a': 42}));
      });

      test('simple example with scalar return', () {
        final doc = YamlEditor('{a: {d: 4}, c: ~}');
        var result = doc.parseAt(['b'], orElse: 42);

        expect(result, isA<YamlScalar>());
        expect(result.value, equals(42));
      });

      test('simple example with symbol return', () {
        final doc = YamlEditor('{a: {d: 4}, c: ~}');
        var result = doc.parseAt(['b'], orElse: #doesNotExist);

        expect(result, isA<YamlScalar>());
        expect(result.value, equals(#doesNotExist));
      });
    });
  });

  group('assign', () {
    test('empty document', () {
      final doc = YamlEditor('');
      doc.assign([], 'replacement');

      expect(doc.toString(), equals('replacement'));
      expectYamlBuilderValue(doc, 'replacement');
    });

    test('replaces string in document containing only a string', () {
      final doc = YamlEditor('test');
      doc.assign([], 'replacement');

      expect(doc.toString(), equals('replacement'));
      expectYamlBuilderValue(doc, 'replacement');
    });

    test('replaces top-level string to map', () {
      final doc = YamlEditor('test');
      doc.assign([], {'a': 1});

      expect(doc.toString(), equals('{a: 1}'));
      expectYamlBuilderValue(doc, {'a': 1});
    });

    test('replaces top-level list', () {
      final doc = YamlEditor('- 1');
      doc.assign([], 'replacement');

      expect(doc.toString(), equals('replacement'));
      expectYamlBuilderValue(doc, 'replacement');
    });

    test('replaces top-level map', () {
      final doc = YamlEditor('a: 1');
      doc.assign([], 'replacement');

      expect(doc.toString(), equals('replacement'));
      expectYamlBuilderValue(doc, 'replacement');
    });

    test('replaces top-level map with comment', () {
      final doc = YamlEditor('a: 1 # comment');
      doc.assign([], 'replacement');

      expect(doc.toString(), equals('replacement # comment'));
      expectYamlBuilderValue(doc, 'replacement');
    });

    test('throw RangeError in list if index is negative', () {
      final doc = YamlEditor("- YAML Ain't Markup Language");
      expect(() => doc.assign([-1], 'hi'), throwsRangeError);
    });

    test('throw RangeError in list if index is larger than list length', () {
      final doc = YamlEditor("- YAML Ain't Markup Language");
      expect(() => doc.assign([2], 'hi'), throwsRangeError);
    });

    test('throw TypeError in list if index is larger than list length', () {
      final doc = YamlEditor("- YAML Ain't Markup Language");
      expect(() => doc.assign(['a'], 'a'), throwsA(isA<TypeError>()));
    });

    test('throw ArgumentError in list if attempting to set a key of a scalar',
        () {
      final doc = YamlEditor("- YAML Ain't Markup Language");
      expect(() => doc.assign([0, 'a'], 'a'), throwsArgumentError);
    });

    test('simple block map', () {
      final doc = YamlEditor("YAML: YAML Ain't Markup Language");
      doc.assign(['YAML'], 'hi');

      expect(doc.toString(), equals('YAML: hi'));
      expectYamlBuilderValue(doc, {'YAML': 'hi'});
    });

    test('nested structure in simple block map', () {
      final doc = YamlEditor("YAML: YAML Ain't Markup Language");
      doc.assign([
        'YAML'
      ], {
        'YAML': {'YAML': "YAML Ain't Markup Language"}
      });

      expect(doc.toString(), equals('''YAML: 
  YAML: 
    YAML: YAML Ain't Markup Language'''));
      expectYamlBuilderValue(doc, {
        'YAML': {
          'YAML': {'YAML': "YAML Ain't Markup Language"}
        }
      });
    });

    test('simple block map with comment', () {
      final doc = YamlEditor("YAML: YAML Ain't Markup Language # comment");
      doc.assign(['YAML'], 'hi');

      expect(doc.toString(), equals('YAML: hi # comment'));
      expectYamlBuilderValue(doc, {'YAML': 'hi'});
    });

    test('simple block map (2) ', () {
      final doc = YamlEditor('''
a: 1
b: 2
c: 3
''');
      doc.assign(['d'], 4);
      expect(doc.toString(), equals('''
a: 1
b: 2
c: 3
d: 4
'''));
      expectYamlBuilderValue(doc, {'a': 1, 'b': 2, 'c': 3, 'd': 4});
    });

    test('simple block map (3)', () {
      final doc = YamlEditor('''
a: 1
''');
      doc.assign(['b'], 2);
      expect(doc.toString(), equals('''
a: 1
b: 2
'''));
      expectYamlBuilderValue(doc, {'a': 1, 'b': 2});
    });

    test('simple block map (4)', () {
      final doc = YamlEditor('a: 1');
      doc.assign(['b'], 2);
      expect(doc.toString(), equals('''a: 1
b: 2
'''));
      expectYamlBuilderValue(doc, {'a': 1, 'b': 2});
    });

    test('simple block map with trailing newline', () {
      final doc = YamlEditor('''
a: 1
b: 2
c: 3


''');
      doc.assign(['d'], 4);
      expect(doc.toString(), equals('''
a: 1
b: 2
c: 3
d: 4


'''));
      expectYamlBuilderValue(doc, {'a': 1, 'b': 2, 'c': 3, 'd': 4});
    });

    test('simple flow map', () {
      final doc = YamlEditor("{YAML: YAML Ain't Markup Language}");
      doc.assign(['YAML'], 'hi');

      expect(doc.toString(), equals('{YAML: hi}'));
      expectYamlBuilderValue(doc, {'YAML': 'hi'});
    });

    test('simple flow map (2)', () {
      final doc = YamlEditor('{}');
      doc.assign(['YAML'], 'hi');

      expect(doc.toString(), equals('{YAML: hi}'));
      expectYamlBuilderValue(doc, {'YAML': 'hi'});
    });

    test('simple flow map (3)', () {
      final doc = YamlEditor("{YAML: YAML Ain't Markup Language}");
      doc.assign(['XML'], 'Extensible Markup Language');

      expect(
          doc.toString(),
          equals(
              "{YAML: YAML Ain't Markup Language, XML: Extensible Markup Language}"));
      expectYamlBuilderValue(doc, {
        'YAML': "YAML Ain't Markup Language",
        'XML': 'Extensible Markup Language'
      });
    });

    test('simple flow map (4)', () {
      final doc = YamlEditor('{No: No}');
      doc.assign(['false'], 'false');

      expect(doc.toString(), equals("{No: No, 'false': 'false'}"));
      expectYamlBuilderValue(doc, {'No': 'No', 'false': 'false'});
    });

    test('simple flow map (5)', () {
      final doc = YamlEditor('''
~: null
false: false
No: No
true: true
''');
      doc.assign([null], 'tilde');
      doc.assign([false], false);
      doc.assign(['No'], 'no');
      doc.assign([true], 'true');

      expect(doc.toString(), equals('''
~: tilde
false: false
No: no
true: 'true'
'''));

      expectYamlBuilderValue(
          doc, {null: 'tilde', false: false, 'No': 'no', true: 'true'});
    });

    test('simple flow map (6)', () {
      final doc = YamlEditor("{YAML: YAML Ain't Markup Language}");
      doc.assign(['YAML'], '> hi');

      expect(doc.toString(), equals("{YAML: '> hi'}"));
      expectYamlBuilderValue(doc, {'YAML': '> hi'});
    });

    test('simple flow map (7)', () {
      final doc = YamlEditor('{[1,2,3]: a}');
      doc.assign([
        [1, 2, 3]
      ], 'sums to 6');

      expect(doc.toString(), equals('{[1,2,3]: sums to 6}'));
      expectYamlBuilderValue(doc, {
        [1, 2, 3]: 'sums to 6'
      });
    });

    test('simple flow map (8)', () {
      final doc = YamlEditor('{{a: 1}: a}');
      doc.assign([
        {'a': 1}
      ], 'sums to 6');

      expect(doc.toString(), equals('{{a: 1}: sums to 6}'));
      expectYamlBuilderValue(doc, {
        {'a': 1}: 'sums to 6'
      });
    });

    test('simple flow map with spacing', () {
      final doc = YamlEditor("{YAML:  YAML Ain't Markup Language }");
      doc.assign(['YAML'], 'hi');

      expect(doc.toString(), equals('{YAML:  hi}'));
      expectYamlBuilderValue(doc, {'YAML': 'hi'});
    });

    test('simple flow map with spacing (2)', () {
      final doc = YamlEditor(
          "{ YAML:  YAML Ain't Markup Language , XML: Extensible Markup Language , HTML: Hypertext Markup Language }");
      doc.assign(['XML'], 'XML Markup Language');

      expect(
          doc.toString(),
          equals(
              "{ YAML:  YAML Ain't Markup Language , XML: XML Markup Language, HTML: Hypertext Markup Language }"));
      expectYamlBuilderValue(doc, {
        'YAML': "YAML Ain't Markup Language",
        'XML': 'XML Markup Language',
        'HTML': 'Hypertext Markup Language'
      });
    });

    test('simple block list', () {
      final doc = YamlEditor("- YAML Ain't Markup Language");
      doc.assign([0], 'hi');

      expect(doc.toString(), equals('- hi'));
      expectYamlBuilderValue(doc, ['hi']);
    });

    test('simple block list (2)', () {
      final doc = YamlEditor("- YAML Ain't Markup Language");
      doc.assign([0], [1, 2]);

      expect(doc.toString(), equals('- \n  - 1\n  - 2'));
      expectYamlBuilderValue(doc, [
        [1, 2]
      ]);
    });

    test('simple block list with comment', () {
      final doc = YamlEditor("- YAML Ain't Markup Language # comment");
      doc.assign([0], 'hi');

      expect(doc.toString(), equals('- hi # comment'));
      expectYamlBuilderValue(doc, ['hi']);
    });

    test('simple block list with comment and spaces', () {
      final doc = YamlEditor("-  YAML Ain't Markup Language  # comment");
      doc.assign([0], 'hi');

      expect(doc.toString(), equals('-  hi  # comment'));
      expectYamlBuilderValue(doc, ['hi']);
    });

    test('simple flow list', () {
      final doc = YamlEditor("[YAML Ain't Markup Language]");
      doc.assign([0], 'hi');

      expect(doc.toString(), equals('[hi]'));
      expectYamlBuilderValue(doc, ['hi']);
    });

    test('simple flow list (2)', () {
      final doc = YamlEditor("[YAML Ain't Markup Language]");
      doc.assign([0], [1, 2, 3]);

      expect(doc.toString(), equals('[[1, 2, 3]]'));
      expectYamlBuilderValue(doc, [
        [1, 2, 3]
      ]);
    });

    test('simple flow list with spacing', () {
      final doc = YamlEditor("[ YAML Ain't Markup Language ]");
      doc.assign([0], 'hi');

      expect(doc.toString(), equals('[ hi]'));
      expectYamlBuilderValue(doc, ['hi']);
    });

    test('simple flow list with spacing (2)', () {
      final doc = YamlEditor('[ 0 , 1 , 2 , 3 ]');
      doc.assign([1], 4);

      expect(doc.toString(), equals('[ 0 , 4, 2 , 3 ]'));
      expectYamlBuilderValue(doc, [0, 4, 2, 3]);
    });

    test('nested block map', () {
      final doc = YamlEditor('''
a: 1
b: 
  d: 4
  e: 5
c: 3
''');
      doc.assign(['b', 'e'], 6);

      expect(doc.toString(), equals('''
a: 1
b: 
  d: 4
  e: 6
c: 3
'''));

      expectYamlBuilderValue(doc, {
        'a': 1,
        'b': {'d': 4, 'e': 6},
        'c': 3
      });
    });

    test('nested block map (2)', () {
      final doc = YamlEditor('''
a: 1
b: {d: 4, e: 5}
c: 3
''');
      doc.assign(['b', 'e'], 6);

      expect(doc.toString(), equals('''
a: 1
b: {d: 4, e: 6}
c: 3
'''));
      expectYamlBuilderValue(doc, {
        'a': 1,
        'b': {'d': 4, 'e': 6},
        'c': 3
      });
    });

    test('nested block map scalar -> flow list', () {
      final doc = YamlEditor('''
a: 1
b: 
  d: 4
  e: 5
c: 3
''');
      doc.assign(['b', 'e'], [1, 2, 3]);

      expect(doc.toString(), equals('''
a: 1
b: 
  d: 4
  e: 
    - 1
    - 2
    - 3
c: 3
'''));
      expectYamlBuilderValue(doc, {
        'a': 1,
        'b': {
          'd': 4,
          'e': [1, 2, 3]
        },
        'c': 3
      });
    });

    test('nested block map -> scalar', () {
      final doc = YamlEditor('''
a: 1
b: 
  d: 4
  e: 5
c: 3
''');
      doc.assign(['b'], 2);

      expect(doc.toString(), equals('''
a: 1
b: 2
c: 3
'''));
      expectYamlBuilderValue(doc, {'a': 1, 'b': 2, 'c': 3});
    });

    test('nested block map -> scalar (2)', () {
      final doc = YamlEditor('''
a: 1
b: 
  d: 4
  e: 5


# comment
''');
      doc.assign(['b'], 2);

      expect(doc.toString(), equals('''
a: 1
b: 2


# comment
'''));
      expectYamlBuilderValue(doc, {
        'a': 1,
        'b': 2,
      });
    });

    test('nested block map scalar -> flow map', () {
      final doc = YamlEditor('''
a: 1
b: 
  d: 4
  e: 5
c: 3
''');
      doc.assign(['b', 'e'], {'x': 3, 'y': 4});

      expect(doc.toString(), equals('''
a: 1
b: 
  d: 4
  e: 
    x: 3
    y: 4
c: 3
'''));
      expectYamlBuilderValue(doc, {
        'a': 1,
        'b': {
          'd': 4,
          'e': {'x': 3, 'y': 4}
        },
        'c': 3
      });
    });

    test('nested block map with comments', () {
      final doc = YamlEditor('''
a: 1
b: 
  d: 4
  e: 5 # comment
c: 3
''');
      doc.assign(['b', 'e'], 6);

      expect(doc.toString(), equals('''
a: 1
b: 
  d: 4
  e: 6 # comment
c: 3
'''));
      expectYamlBuilderValue(doc, {
        'a': 1,
        'b': {'d': 4, 'e': 6},
        'c': 3
      });
    });

    test('nested block map with comments (2)', () {
      final doc = YamlEditor('''
a: 1
b: 
  d: 4 # comment
# comment
  e: 5 # comment
# comment
c: 3
''');
      doc.assign(['b', 'e'], 6);

      expect(doc.toString(), equals('''
a: 1
b: 
  d: 4 # comment
# comment
  e: 6 # comment
# comment
c: 3
'''));
      expectYamlBuilderValue(doc, {
        'a': 1,
        'b': {'d': 4, 'e': 6},
        'c': 3
      });
    });

    test('nested list', () {
      final doc = YamlEditor('''
- 0
- - 0
  - 1
  - 2
- 2
- 3
''');
      doc.assign([1, 1], 4);
      expect(doc.toString(), equals('''
- 0
- - 0
  - 4
  - 2
- 2
- 3
'''));

      expectYamlBuilderValue(doc, [
        0,
        [0, 4, 2],
        2,
        3
      ]);
    });

    test('nested list flow map -> scalar', () {
      final doc = YamlEditor('''
- 0
- {a: 1, b: 2}
- 2
- 3
''');
      doc.assign([1], 4);
      expect(doc.toString(), equals('''
- 0
- 4
- 2
- 3
'''));
      expectYamlBuilderValue(doc, [0, 4, 2, 3]);
    });

    test('nested list-map-list-number update', () {
      final doc = YamlEditor('''
- 0
- a:
   - 1
   - 2
   - 3
- 2
- 3
''');
      doc.assign([1, 'a', 0], 15);
      expect(doc.toString(), equals('''
- 0
- a:
   - 15
   - 2
   - 3
- 2
- 3
'''));
      expectYamlBuilderValue(doc, [
        0,
        {
          'a': [15, 2, 3]
        },
        2,
        3
      ]);
    });

    test('empty flow map ', () {
      final doc = YamlEditor('{}');
      doc.assign(['a'], 1);
      expect(doc.toString(), equals('{a: 1}'));
      expectYamlBuilderValue(doc, {'a': 1});
    });
  });

  group('remove', () {
    test('throws ArgumentError if collectionPath points to a scalar', () {
      final doc = YamlEditor('''
a: 1
b: 2
c: 3
''');

      expect(() => doc.remove(['a', 0]), throwsArgumentError);
    });

    test('throws ArgumentError if collectionPath is invalid', () {
      final doc = YamlEditor('''
a: 1
b: 2
c: 3
''');

      expect(() => doc.remove(['d']), throwsArgumentError);
    });

    test('throws ArgumentError if collectionPath is invalid - list', () {
      final doc = YamlEditor('''
[1, 2, 3]
''');

      expect(() => doc.remove([4]), throwsArgumentError);
    });

    test('empty path should clear string', () {
      final doc = YamlEditor('''
a: 1
b: 2
c: [3, 4]
''');
      doc.remove([]);
      expect(doc.toString(), equals(''));
    });

    test('simple block map', () {
      final doc = YamlEditor('''
a: 1
b: 2
c: 3
''');
      doc.remove(['b']);
      expect(doc.toString(), equals('''
a: 1
c: 3
'''));
    });

    test('last element in block map should return flow empty map', () {
      final doc = YamlEditor('''
a: 1
''');
      doc.remove(['a']);
      expect(doc.toString(), equals('''
{}
'''));
    });

    test('last element in block map should return flow empty map', () {
      final doc = YamlEditor('''
- a: 1
- b: 2
''');
      doc.remove([0, 'a']);
      expect(doc.toString(), equals('''
- {}
- b: 2
'''));
    });

    test('last element in block list should return flow empty map', () {
      final doc = YamlEditor('''
- 0
''');
      doc.remove([0]);
      expect(doc.toString(), equals('''
[]
'''));
    });

    test('last element in flow list should return flow empty map', () {
      final doc = YamlEditor('''
a: [1]
b: [3]
''');
      doc.remove(['a', 0]);
      expect(doc.toString(), equals('''
a: []
b: [3]
'''));
    });

    test('last element in block list should return flow empty map (2)', () {
      final doc = YamlEditor('''
a: 
  - 1
b: 
  - 3
''');
      doc.remove(['a', 0]);
      expect(doc.toString(), equals('''
a: 
  []
b: 
  - 3
'''));
    });

    test('nested block map', () {
      final doc = YamlEditor('''
a: 1
b: 
  d: 4
  e: 5
c: 3
''');
      doc.remove(['b', 'd']);
      expect(doc.toString(), equals('''
a: 1
b: 
  e: 5
c: 3
'''));
    });

    test('simple flow map ', () {
      final doc = YamlEditor('{a: 1, b: 2, c: 3}');
      doc.remove(['b']);
      expect(doc.toString(), equals('{a: 1, c: 3}'));
    });

    test('simple flow map (2) ', () {
      final doc = YamlEditor('{a: 1}');
      doc.remove(['a']);
      expect(doc.toString(), equals('{}'));
    });

    test('simple flow map (3) ', () {
      final doc = YamlEditor('{a: 1, b: 2}');
      doc.remove(['a']);
      expect(doc.toString(), equals('{ b: 2}'));
    });

    test('nested flow map ', () {
      final doc = YamlEditor('{a: 1, b: {d: 4, e: 5}, c: 3}');
      doc.remove(['b', 'd']);
      expect(doc.toString(), equals('{a: 1, b: { e: 5}, c: 3}'));
    });

    test('simple block list ', () {
      final doc = YamlEditor('''
- 0
- 1
- 2
- 3
''');
      doc.remove([1]);
      expect(doc.toString(), equals('''
- 0
- 2
- 3
'''));
      expectYamlBuilderValue(doc, [0, 2, 3]);
    });

    test('simple block list (2)', () {
      final doc = YamlEditor('''
- 0
- [1,2,3]
- 2
- 3
''');
      doc.remove([1]);
      expect(doc.toString(), equals('''
- 0
- 2
- 3
'''));
      expectYamlBuilderValue(doc, [0, 2, 3]);
    });

    test('simple block list (3)', () {
      final doc = YamlEditor('''
- 0
- {a: 1, b: 2}
- 2
- 3
''');
      doc.remove([1]);
      expect(doc.toString(), equals('''
- 0
- 2
- 3
'''));
      expectYamlBuilderValue(doc, [0, 2, 3]);
    });
    test('simple block list with comments', () {
      final doc = YamlEditor('''
- 0
- 1 # comments
- 2
- 3
''');
      doc.remove([1]);
      expect(doc.toString(), equals('''
- 0
- 2
- 3
'''));
      expectYamlBuilderValue(doc, [0, 2, 3]);
    });

    test('simple flow list', () {
      final doc = YamlEditor('[1, 2, 3]');
      doc.remove([1]);
      expect(doc.toString(), equals('[1, 3]'));
      expectYamlBuilderValue(doc, [1, 3]);
    });

    test('simple flow list (2)', () {
      final doc = YamlEditor('[1, "b", "c"]');
      doc.remove([0]);
      expect(doc.toString(), equals('[ "b", "c"]'));
      expectYamlBuilderValue(doc, ['b', 'c']);
    });

    test('simple flow list (3)', () {
      final doc = YamlEditor('[1, {a: 1}, "c"]');
      doc.remove([1]);
      expect(doc.toString(), equals('[1, "c"]'));
      expectYamlBuilderValue(doc, [1, 'c']);
    });
  });

  group('appendToList', () {
    test('throws ArgumentError if it is a map', () {
      final doc = YamlEditor('a:1');
      expect(() => doc.appendToList([], 4), throwsArgumentError);
    });

    test('throws ArgumentError if it is a scalar', () {
      final doc = YamlEditor('1');
      expect(() => doc.appendToList([], 4), throwsArgumentError);
    });

    test('simple block list ', () {
      final doc = YamlEditor('''
- 0
- 1
- 2
- 3
''');
      doc.appendToList([], 4);
      expect(doc.toString(), equals('''
- 0
- 1
- 2
- 3
- 4
'''));
      expectYamlBuilderValue(doc, [0, 1, 2, 3, 4]);
    });

    test('list to simple block list ', () {
      final doc = YamlEditor('''
- 0
- 1
- 2
- 3
''');
      doc.appendToList([], [4, 5, 6]);
      expect(doc.toString(), equals('''
- 0
- 1
- 2
- 3
- 
  - 4
  - 5
  - 6
'''));
      expectYamlBuilderValue(doc, [
        0,
        1,
        2,
        3,
        [4, 5, 6]
      ]);
    });

    test('nested block list ', () {
      final doc = YamlEditor('''
- 0
- - 1
  - 2
''');
      doc.appendToList([1], 3);
      expect(doc.toString(), equals('''
- 0
- - 1
  - 2
  - 3
'''));
      expectYamlBuilderValue(doc, [
        0,
        [1, 2, 3]
      ]);
    });

    test('block list to nested block list ', () {
      final doc = YamlEditor('''
- 0
- - 1
  - 2
''');
      doc.appendToList([1], [3, 4, 5]);

      expect(doc.toString(), equals('''
- 0
- - 1
  - 2
  - 
    - 3
    - 4
    - 5
'''));
      expectYamlBuilderValue(doc, [
        0,
        [
          1,
          2,
          [3, 4, 5]
        ]
      ]);
    });

    test('simple flow list ', () {
      final doc = YamlEditor('[0, 1, 2]');
      doc.appendToList([], 3);
      expect(doc.toString(), equals('[0, 1, 2, 3]'));
      expectYamlBuilderValue(doc, [0, 1, 2, 3]);
    });

    test('empty flow list ', () {
      final doc = YamlEditor('[]');
      doc.appendToList([], 0);
      expect(doc.toString(), equals('[0]'));
      expectYamlBuilderValue(doc, [0]);
    });
  });

  group('prependToList', () {
    test('throws ArgumentError if it is a map', () {
      final doc = YamlEditor('a:1');
      expect(() => doc.prependToList([], 4), throwsArgumentError);
    });

    test('throws ArgumentError if it is a scalar', () {
      final doc = YamlEditor('1');
      expect(() => doc.prependToList([], 4), throwsArgumentError);
    });

    test('simple flow list', () {
      final doc = YamlEditor('[1, 2]');
      doc.prependToList([], 0);
      expect(doc.toString(), equals('[0, 1, 2]'));
      expectYamlBuilderValue(doc, [0, 1, 2]);
    });

    test('simple flow list with spaces', () {
      final doc = YamlEditor('[ 1 , 2 ]');
      doc.prependToList([], 0);
      expect(doc.toString(), equals('[ 0, 1 , 2 ]'));
      expectYamlBuilderValue(doc, [0, 1, 2]);
    });

    test('simple block list', () {
      final doc = YamlEditor('''
- 1
- 2''');
      doc.prependToList([], 0);
      expect(doc.toString(), equals('''
- 0
- 1
- 2'''));
      expectYamlBuilderValue(doc, [0, 1, 2]);
    });

    test('simple block list (2)', () {
      final doc = YamlEditor('''- 1
- 2''');
      doc.prependToList([], 0);
      expect(doc.toString(), equals('''- 0
- 1
- 2'''));
      expectYamlBuilderValue(doc, [0, 1, 2]);
    });

    test('simple block list (3)', () {
      final doc = YamlEditor('''
- 1
- 2
''');
      doc.prependToList([], 0);
      expect(doc.toString(), equals('''
- 0
- 1
- 2
'''));
      expectYamlBuilderValue(doc, [0, 1, 2]);
    });

    test('simple block list (4)', () {
      final doc = YamlEditor('''
- 1
- 2
''');
      doc.prependToList([], [4, 5, 6]);
      expect(doc.toString(), equals('''
- 
  - 4
  - 5
  - 6
- 1
- 2
'''));
      expectYamlBuilderValue(doc, [
        [4, 5, 6],
        1,
        2
      ]);
    });

    test('simple block list with comments ', () {
      final doc = YamlEditor('''
# comments
- 1 # comments
- 2
''');
      doc.prependToList([], 0);
      expect(doc.toString(), equals('''
# comments
- 0
- 1 # comments
- 2
'''));
      expectYamlBuilderValue(doc, [0, 1, 2]);
    });

    test('block list nested in map', () {
      final doc = YamlEditor('''
a:
  - 1
  - 2
''');
      doc.prependToList(['a'], 0);
      expect(doc.toString(), equals('''
a:
  - 0
  - 1
  - 2
'''));
      expectYamlBuilderValue(doc, {
        'a': [0, 1, 2]
      });
    });

    test('block list nested in map with comments ', () {
      final doc = YamlEditor('''
a: # comments
  - 1 # comments
  - 2
''');
      doc.prependToList(['a'], 0);
      expect(doc.toString(), equals('''
a: # comments
  - 0
  - 1 # comments
  - 2
'''));
      expectYamlBuilderValue(doc, {
        'a': [0, 1, 2]
      });
    });
  });

  group('insertIntoList', () {
    test('throws ArgumentError if it is a map', () {
      final doc = YamlEditor('a:1');
      expect(() => doc.insertIntoList([], 0, 4), throwsArgumentError);
    });

    test('throws ArgumentError if it is a scalar', () {
      final doc = YamlEditor('1');
      expect(() => doc.insertIntoList([], 0, 4), throwsArgumentError);
    });

    test('simple flow list', () {
      final doc = YamlEditor('[1, 2]');
      doc.insertIntoList([], 0, 0);
      expect(doc.toString(), equals('[0, 1, 2]'));
      expectYamlBuilderValue(doc, [0, 1, 2]);
    });

    test('simple flow list (2)', () {
      final doc = YamlEditor('[1, 2]');
      doc.insertIntoList([], 1, 3);
      expect(doc.toString(), equals('[1, 3, 2]'));
      expectYamlBuilderValue(doc, [1, 3, 2]);
    });

    test('simple flow list (3)', () {
      final doc = YamlEditor('[1, 2]');
      doc.insertIntoList([], 2, 3);
      expect(doc.toString(), equals('[1, 2, 3]'));
      expectYamlBuilderValue(doc, [1, 2, 3]);
    });

    test('simple block list', () {
      final doc = YamlEditor('''
- 1
- 2''');
      doc.insertIntoList([], 0, 0);
      expect(doc.toString(), equals('''
- 0
- 1
- 2'''));
      expectYamlBuilderValue(doc, [0, 1, 2]);
    });

    test('simple block list (2)', () {
      final doc = YamlEditor('''
- 1
- 2''');
      doc.insertIntoList([], 1, 3);
      expect(doc.toString(), equals('''
- 1
- 3
- 2'''));
      expectYamlBuilderValue(doc, [1, 3, 2]);
    });

    test('simple block list (3)', () {
      final doc = YamlEditor('''
- 1
- 2
''');
      doc.insertIntoList([], 2, 3);
      expect(doc.toString(), equals('''
- 1
- 2
- 3
'''));
      expectYamlBuilderValue(doc, [1, 2, 3]);
    });

    test('simple block list (4)', () {
      final doc = YamlEditor('''
- 1
- 3
''');
      doc.insertIntoList([], 1, [4, 5, 6]);
      expect(doc.toString(), equals('''
- 1
- 
  - 4
  - 5
  - 6
- 3
'''));
      expectYamlBuilderValue(doc, [
        1,
        [4, 5, 6],
        3
      ]);
    });

    test('simple block list with comments', () {
      final doc = YamlEditor('''
- 0 # comment a
- 2 # comment b
''');
      doc.insertIntoList([], 1, 1);
      expect(doc.toString(), equals('''
- 0 # comment a
- 1
- 2 # comment b
'''));
      expectYamlBuilderValue(doc, [0, 1, 2]);
    });
  });

  group('spliceList', () {
    test(
        'throws ArgumentError if invalid index + deleteCount combination is passed in',
        () {
      final doc = YamlEditor('[0, 0]');
      expect(() => doc.spliceList([], 1, 5, [1, 2]), throwsArgumentError);
    });

    test('simple block list', () {
      final doc = YamlEditor('''
- 0
- 0
''');
      final nodes = doc.spliceList([], 1, 1, [1, 2]);
      expect(doc.toString(), equals('''
- 0
- 1
- 2
'''));

      expectDeepEquals(nodes.toList(), [0]);
    });

    test('simple block list (2)', () {
      final doc = YamlEditor('''
- 0
- 0
''');
      final nodes = doc.spliceList([], 0, 2, [0, 1, 2]);
      expect(doc.toString(), equals('''
- 0
- 1
- 2
'''));

      expectDeepEquals(nodes.toList(), [0, 0]);
    });

    test('simple block list (3)', () {
      final doc = YamlEditor('''
- Jan
- March
- April
- June
''');
      final nodes = doc.spliceList([], 1, 0, ['Feb']);
      expect(doc.toString(), equals('''
- Jan
- Feb
- March
- April
- June
'''));

      expectDeepEquals(nodes.toList(), []);

      final nodes2 = doc.spliceList([], 4, 1, ['May']);
      expect(doc.toString(), equals('''
- Jan
- Feb
- March
- April
- May
'''));

      expectDeepEquals(nodes2.toList(), ['June']);
    });

    test('simple flow list', () {
      final doc = YamlEditor('[0, 0]');
      final nodes = doc.spliceList([], 1, 1, [1, 2]);
      expect(doc.toString(), equals('[0, 1, 2]'));

      expectDeepEquals(nodes.toList(), [0]);
    });

    test('simple flow list (2)', () {
      final doc = YamlEditor('[0, 0]');
      final nodes = doc.spliceList([], 0, 2, [0, 1, 2]);
      expect(doc.toString(), equals('[0, 1, 2]'));

      expectDeepEquals(nodes.toList(), [0, 0]);
    });
  });

  group('YamlEditor records edits', () {
    test('returns empty list at start', () {
      final yamlEditor = YamlEditor('YAML: YAML');

      expect(yamlEditor.edits, []);
    });

    test('after one change', () {
      final yamlEditor = YamlEditor('YAML: YAML');
      yamlEditor.assign(['YAML'], "YAML Ain't Markup Language");

      expect(
          yamlEditor.edits, [SourceEdit(6, 4, "YAML Ain't Markup Language")]);
    });

    test('after multiple changes', () {
      final yamlEditor = YamlEditor('YAML: YAML');
      yamlEditor.assign(['YAML'], "YAML Ain't Markup Language");
      yamlEditor.assign(['XML'], 'Extensible Markup Language');
      yamlEditor.remove(['YAML']);

      expect(yamlEditor.edits, [
        SourceEdit(6, 4, "YAML Ain't Markup Language"),
        SourceEdit(32, 0, '\nXML: Extensible Markup Language\n'),
        SourceEdit(0, 32, '')
      ]);
    });

    test('that do not automatically update with internal list', () {
      final yamlEditor = YamlEditor('YAML: YAML');
      yamlEditor.assign(['YAML'], "YAML Ain't Markup Language");

      final firstEdits = yamlEditor.edits;

      expect(firstEdits, [SourceEdit(6, 4, "YAML Ain't Markup Language")]);

      yamlEditor.assign(['XML'], 'Extensible Markup Language');
      yamlEditor.remove(['YAML']);

      expect(firstEdits, [SourceEdit(6, 4, "YAML Ain't Markup Language")]);
      expect(yamlEditor.edits, [
        SourceEdit(6, 4, "YAML Ain't Markup Language"),
        SourceEdit(32, 0, '\nXML: Extensible Markup Language\n'),
        SourceEdit(0, 32, '')
      ]);
    });
  });
}
