import 'package:test/test.dart';
import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

import 'mod_utils.dart';

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

  group('parseValueAt', () {
    test('returns the expected value', () {
      var doc = YamlEditBuilder("YAML: YAML Ain't Markup Language");

      expect(doc.parseValueAt(['YAML']).value, "YAML Ain't Markup Language");
    });

    group('returns a YamlNode', () {
      test('with the correct type', () {
        var doc = YamlEditBuilder("YAML: YAML Ain't Markup Language");
        var expectedYamlScalar = doc.parseValueAt(['YAML']);

        expect(expectedYamlScalar is YamlScalar, equals(true));
      });

      test('with the correct type (2)', () {
        var doc = YamlEditBuilder("YAML: YAML Ain't Markup Language");
        var expectedYamlMap = doc.parseValueAt([]);

        expect(expectedYamlMap is YamlMap, equals(true));
      });

      test('that is immutable', () {
        var doc = YamlEditBuilder("YAML: YAML Ain't Markup Language");
        var expectedYamlMap = doc.parseValueAt([]);

        expect(() => (expectedYamlMap as YamlMap)['YAML'] = 'test',
            throwsUnsupportedError);
      });

      test('that has immutable children', () {
        var doc = YamlEditBuilder("YAML: ['Y', 'A', 'M', 'L']");
        var expectedYamlMap = doc.parseValueAt([]);

        expect(() => (expectedYamlMap as YamlMap)['YAML'][0] = 'X',
            throwsUnsupportedError);
      });
    });
  });

  group('setIn', () {
    test('simple block map', () {
      var doc = YamlEditBuilder("YAML: YAML Ain't Markup Language");
      doc.setIn(['YAML'], 'hi');

      expect(doc.toString(), equals('YAML: hi'));
      expectYamlBuilderValue(doc, {'YAML': 'hi'});
    });

    test('simple block map with comment', () {
      var doc = YamlEditBuilder("YAML: YAML Ain't Markup Language # comment");
      doc.setIn(['YAML'], 'hi');

      expect(doc.toString(), equals('YAML: hi # comment'));
      expectYamlBuilderValue(doc, {'YAML': 'hi'});
    });

    test('simple block map ', () {
      var doc = YamlEditBuilder('''
a: 1
b: 2
c: 3
''');
      doc.setIn(['d'], 4);
      expect(doc.toString(), equals('''
a: 1
b: 2
c: 3
d: 4
'''));
      expectYamlBuilderValue(doc, {'a': 1, 'b': 2, 'c': 3, 'd': 4});
    });

    test('simple block map (2)', () {
      var doc = YamlEditBuilder('''
a: 1
''');
      doc.setIn(['b'], 2);
      expect(doc.toString(), equals('''
a: 1
b: 2
'''));
      expectYamlBuilderValue(doc, {'a': 1, 'b': 2});
    });

    test('simple block map (3)', () {
      var doc = YamlEditBuilder('a: 1');
      doc.setIn(['b'], 2);
      expect(doc.toString(), equals('''a: 1
b: 2
'''));
      expectYamlBuilderValue(doc, {'a': 1, 'b': 2});
    });

    test('simple block map with trailing newline', () {
      var doc = YamlEditBuilder('''
a: 1
b: 2
c: 3


''');
      doc.setIn(['d'], 4);
      expect(doc.toString(), equals('''
a: 1
b: 2
c: 3
d: 4


'''));
      expectYamlBuilderValue(doc, {'a': 1, 'b': 2, 'c': 3, 'd': 4});
    });

    test('simple flow map', () {
      var doc = YamlEditBuilder("{YAML: YAML Ain't Markup Language}");
      doc.setIn(['YAML'], 'hi');

      expect(doc.toString(), equals('{YAML: hi}'));
      expectYamlBuilderValue(doc, {'YAML': 'hi'});
    });

    test('simple flow map with spacing', () {
      var doc = YamlEditBuilder("{YAML:  YAML Ain't Markup Language }");
      doc.setIn(['YAML'], 'hi');

      expect(doc.toString(), equals('{YAML:  hi}'));
      expectYamlBuilderValue(doc, {'YAML': 'hi'});
    });

    test('simple flow map with spacing (2)', () {
      var doc = YamlEditBuilder(
          "{ YAML:  YAML Ain't Markup Language , XML: Extensible Markup Language , HTML: Hypertext Markup Language }");
      doc.setIn(['XML'], 'XML Markup Language');

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

    test('throw RangeError in list if index is negative', () {
      var doc = YamlEditBuilder("- YAML Ain't Markup Language");
      expect(() => doc.setIn([-1], 'hi'), throwsRangeError);
    });

    test('throw RangeError in list if index is larger than list length', () {
      var doc = YamlEditBuilder("- YAML Ain't Markup Language");
      expect(() => doc.setIn([2], 'hi'), throwsRangeError);
    });

    test('simple block list', () {
      var doc = YamlEditBuilder("- YAML Ain't Markup Language");
      doc.setIn([0], 'hi');

      expect(doc.toString(), equals('- hi'));
      expectYamlBuilderValue(doc, ['hi']);
    });

    test('simple block list with comment', () {
      var doc = YamlEditBuilder("- YAML Ain't Markup Language # comment");
      doc.setIn([0], 'hi');

      expect(doc.toString(), equals('- hi # comment'));
      expectYamlBuilderValue(doc, ['hi']);
    });

    test('simple block list with comment and spaces', () {
      var doc = YamlEditBuilder("-  YAML Ain't Markup Language  # comment");
      doc.setIn([0], 'hi');

      expect(doc.toString(), equals('-  hi  # comment'));
      expectYamlBuilderValue(doc, ['hi']);
    });

    test('simple flow list', () {
      var doc = YamlEditBuilder("[YAML Ain't Markup Language]");
      doc.setIn([0], 'hi');

      expect(doc.toString(), equals('[hi]'));
      expectYamlBuilderValue(doc, ['hi']);
    });

    test('simple flow list with spacing', () {
      var doc = YamlEditBuilder("[ YAML Ain't Markup Language ]");
      doc.setIn([0], 'hi');

      expect(doc.toString(), equals('[ hi]'));
      expectYamlBuilderValue(doc, ['hi']);
    });

    test('simple flow list with spacing (2)', () {
      var doc = YamlEditBuilder('[ 0 , 1 , 2 , 3 ]');
      doc.setIn([1], 4);

      expect(doc.toString(), equals('[ 0 , 4, 2 , 3 ]'));
      expectYamlBuilderValue(doc, [0, 4, 2, 3]);
    });

    test('nested block map', () {
      var doc = YamlEditBuilder('''
a: 1
b: 
  d: 4
  e: 5
c: 3
''');
      doc.setIn(['b', 'e'], 6);

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
      var doc = YamlEditBuilder('''
a: 1
b: {d: 4, e: 5}
c: 3
''');
      doc.setIn(['b', 'e'], 6);

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
      var doc = YamlEditBuilder('''
a: 1
b: 
  d: 4
  e: 5
c: 3
''');
      doc.setIn(['b', 'e'], [1, 2, 3]);

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
      var doc = YamlEditBuilder('''
a: 1
b: 
  d: 4
  e: 5
c: 3
''');
      doc.setIn(['b'], 2);

      expect(doc.toString(), equals('''
a: 1
b: 2
c: 3
'''));
      expectYamlBuilderValue(doc, {'a': 1, 'b': 2, 'c': 3});
    });

    test('nested block map -> scalar (2)', () {
      var doc = YamlEditBuilder('''
a: 1
b: 
  d: 4
  e: 5


# comment
''');
      doc.setIn(['b'], 2);

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
      var doc = YamlEditBuilder('''
a: 1
b: 
  d: 4
  e: 5
c: 3
''');
      doc.setIn(['b', 'e'], {'x': 3, 'y': 4});

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
      var doc = YamlEditBuilder('''
a: 1
b: 
  d: 4
  e: 5 # comment
c: 3
''');
      doc.setIn(['b', 'e'], 6);

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
      var doc = YamlEditBuilder('''
a: 1
b: 
  d: 4 # comment
# comment
  e: 5 # comment
# comment
c: 3
''');
      doc.setIn(['b', 'e'], 6);

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
      var doc = YamlEditBuilder('''
- 0
- - 0
  - 1
  - 2
- 2
- 3
''');
      doc.setIn([1, 1], 4);
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
      var doc = YamlEditBuilder('''
- 0
- {a: 1, b: 2}
- 2
- 3
''');
      doc.setIn([1], 4);
      expect(doc.toString(), equals('''
- 0
- 4
- 2
- 3
'''));
      expectYamlBuilderValue(doc, [0, 4, 2, 3]);
    });

    test('nested list-map-list-number update', () {
      var doc = YamlEditBuilder('''
- 0
- a:
   - 1
   - 2
   - 3
- 2
- 3
''');
      doc.setIn([1, 'a', 0], 15);
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
      var doc = YamlEditBuilder('{}');
      doc.setIn(['a'], 1);
      expect(doc.toString(), equals('{a: 1}'));
      expectYamlBuilderValue(doc, {'a': 1});
    });
  });

  group('removeIn', () {
    test('simple block map', () {
      var doc = YamlEditBuilder('''
a: 1
b: 2
c: 3
''');
      doc.removeIn(['b']);
      expect(doc.toString(), equals('''
a: 1
c: 3
'''));
    });

    test('nested block map', () {
      var doc = YamlEditBuilder('''
a: 1
b: 
  d: 4
  e: 5
c: 3
''');
      doc.removeIn(['b', 'd']);
      expect(doc.toString(), equals('''
a: 1
b: 
  e: 5
c: 3
'''));
    });

    test('simple flow map ', () {
      var doc = YamlEditBuilder('{a: 1, b: 2, c: 3}');
      doc.removeIn(['b']);
      expect(doc.toString(), equals('{a: 1, c: 3}'));
    });

    test('nested flow map ', () {
      var doc = YamlEditBuilder('{a: 1, b: {d: 4, e: 5}, c: 3}');
      doc.removeIn(['b', 'd']);
      expect(doc.toString(), equals('{a: 1, b: { e: 5}, c: 3}'));
    });

    test('simple block list ', () {
      var doc = YamlEditBuilder('''
- 0
- 1
- 2
- 3
''');
      doc.removeIn([1]);
      expect(doc.toString(), equals('''
- 0
- 2
- 3
'''));
      expectYamlBuilderValue(doc, [0, 2, 3]);
    });

    test('simple block list (2)', () {
      var doc = YamlEditBuilder('''
- 0
- [1,2,3]
- 2
- 3
''');
      doc.removeIn([1]);
      expect(doc.toString(), equals('''
- 0
- 2
- 3
'''));
      expectYamlBuilderValue(doc, [0, 2, 3]);
    });

    test('simple block list (3)', () {
      var doc = YamlEditBuilder('''
- 0
- {a: 1, b: 2}
- 2
- 3
''');
      doc.removeIn([1]);
      expect(doc.toString(), equals('''
- 0
- 2
- 3
'''));
      expectYamlBuilderValue(doc, [0, 2, 3]);
    });
    test('simple block list with comments', () {
      var doc = YamlEditBuilder('''
- 0
- 1 # comments
- 2
- 3
''');
      doc.removeIn([1]);
      expect(doc.toString(), equals('''
- 0
- 2
- 3
'''));
      expectYamlBuilderValue(doc, [0, 2, 3]);
    });

    test('simple flow list', () {
      var doc = YamlEditBuilder('[1, 2, 3]');
      doc.removeIn([1]);
      expect(doc.toString(), equals('[1, 3]'));
      expectYamlBuilderValue(doc, [1, 3]);
    });

    test('simple flow list (2)', () {
      var doc = YamlEditBuilder('[1, "b", "c"]');
      doc.removeIn([1]);
      expect(doc.toString(), equals('[1, "c"]'));
      expectYamlBuilderValue(doc, [1, 'c']);
    });

    test('simple flow list (3)', () {
      var doc = YamlEditBuilder('[1, {a: 1}, "c"]');
      doc.removeIn([1]);
      expect(doc.toString(), equals('[1, "c"]'));
      expectYamlBuilderValue(doc, [1, 'c']);
    });
  });

  group('addInList', () {
    test('simple block list ', () {
      var doc = YamlEditBuilder('''
- 0
- 1
- 2
- 3
''');
      doc.addInList([], 4);
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
      var doc = YamlEditBuilder('''
- 0
- 1
- 2
- 3
''');
      doc.addInList([], [4, 5, 6]);
      expect(doc.toString(), equals('''
- 0
- 1
- 2
- 3
- - 4
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
      var doc = YamlEditBuilder('''
- 0
- - 1
  - 2
''');
      doc.addInList([1], 3);
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
      var doc = YamlEditBuilder('''
- 0
- - 1
  - 2
''');
      doc.addInList([1], [3, 4, 5]);

      expect(doc.toString(), equals('''
- 0
- - 1
  - 2
  - - 3
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
      var doc = YamlEditBuilder('[0, 1, 2]');
      doc.addInList([], 3);
      expect(doc.toString(), equals('[0, 1, 2, 3]'));
      expectYamlBuilderValue(doc, [0, 1, 2, 3]);
    });

    test('empty flow list ', () {
      var doc = YamlEditBuilder('[]');
      doc.addInList([], 0);
      expect(doc.toString(), equals('[0]'));
      expectYamlBuilderValue(doc, [0]);
    });
  });

  group('prependInList', () {
    test('simple flow list', () {
      var doc = YamlEditBuilder('[1, 2]');
      doc.prependInList([], 0);
      expect(doc.toString(), equals('[0, 1, 2]'));
      expectYamlBuilderValue(doc, [0, 1, 2]);
    });

    test('simple flow list with spaces', () {
      var doc = YamlEditBuilder('[ 1 , 2 ]');
      doc.prependInList([], 0);
      expect(doc.toString(), equals('[0,  1 , 2 ]'));
      expectYamlBuilderValue(doc, [0, 1, 2]);
    });

    test('simple block list', () {
      var doc = YamlEditBuilder('''
- 1
- 2''');
      doc.prependInList([], 0);
      expect(doc.toString(), equals('''
- 0
- 1
- 2'''));
      expectYamlBuilderValue(doc, [0, 1, 2]);
    });

    test('simple block list (2)', () {
      var doc = YamlEditBuilder('''- 1
- 2''');
      doc.prependInList([], 0);
      expect(doc.toString(), equals('''- 0
- 1
- 2'''));
      expectYamlBuilderValue(doc, [0, 1, 2]);
    });

    test('simple block list (3)', () {
      var doc = YamlEditBuilder('''
- 1
- 2
''');
      doc.prependInList([], 0);
      expect(doc.toString(), equals('''
- 0
- 1
- 2
'''));
      expectYamlBuilderValue(doc, [0, 1, 2]);
    });

    test('simple block list with comments ', () {
      var doc = YamlEditBuilder('''
# comments
- 1 # comments
- 2
''');
      doc.prependInList([], 0);
      expect(doc.toString(), equals('''
# comments
- 0
- 1 # comments
- 2
'''));
      expectYamlBuilderValue(doc, [0, 1, 2]);
    });

    test('block list nested in map', () {
      var doc = YamlEditBuilder('''
a:
  - 1
  - 2
''');
      doc.prependInList(['a'], 0);
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
      var doc = YamlEditBuilder('''
a: # comments
  - 1 # comments
  - 2
''');
      doc.prependInList(['a'], 0);
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

  group('insertInList', () {
    test('simple flow list', () {
      var doc = YamlEditBuilder('[1, 2]');
      doc.insertInList([], 0, 0);
      expect(doc.toString(), equals('[0, 1, 2]'));
      expectYamlBuilderValue(doc, [0, 1, 2]);
    });

    test('simple flow list (2)', () {
      var doc = YamlEditBuilder('[1, 2]');
      doc.insertInList([], 1, 3);
      expect(doc.toString(), equals('[1, 3, 2]'));
      expectYamlBuilderValue(doc, [1, 3, 2]);
    });

    test('simple flow list (3)', () {
      var doc = YamlEditBuilder('[1, 2]');
      doc.insertInList([], 2, 3);
      expect(doc.toString(), equals('[1, 2, 3]'));
      expectYamlBuilderValue(doc, [1, 2, 3]);
    });

    test('simple block list', () {
      var doc = YamlEditBuilder('''
- 1
- 2''');
      doc.insertInList([], 0, 0);
      expect(doc.toString(), equals('''
- 0
- 1
- 2'''));
      expectYamlBuilderValue(doc, [0, 1, 2]);
    });

    test('simple block list (2)', () {
      var doc = YamlEditBuilder('''
- 1
- 2''');
      doc.insertInList([], 1, 3);
      expect(doc.toString(), equals('''
- 1
- 3
- 2'''));
      expectYamlBuilderValue(doc, [1, 3, 2]);
    });

    test('simple block list (3)', () {
      var doc = YamlEditBuilder('''
- 1
- 2
''');
      doc.insertInList([], 2, 3);
      expect(doc.toString(), equals('''
- 1
- 2
- 3
'''));
      expectYamlBuilderValue(doc, [1, 2, 3]);
    });
  });
}
