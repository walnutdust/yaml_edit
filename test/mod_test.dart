import 'package:test/test.dart';
import 'package:yaml_edit/src/mod.dart';

import 'mod_utils.dart';

void main() {
  group('preserves original yaml: ', () {
    test('number', () {
      expectUnchangedYamlAfterLoading('2');
    });

    test('number with leading and trailing lines', () {
      expectUnchangedYamlAfterLoading('''
      
      2
      
      ''');
    });

    test('octal numbers', () {
      expectUnchangedYamlAfterLoading('0o14');
    });

    test('negative numbers', () {
      expectUnchangedYamlAfterLoading('-345');
    });

    test('hexadecimal numbers', () {
      expectUnchangedYamlAfterLoading('0x123abc');
    });

    test('floating point numbers', () {
      expectUnchangedYamlAfterLoading('345.678');
    });

    test('exponential numbers', () {
      expectUnchangedYamlAfterLoading('12.3015e+02');
    });

    test('string', () {
      expectUnchangedYamlAfterLoading('a string');
    });

    test('string with control characters', () {
      expectUnchangedYamlAfterLoading('a string \\n');
    });

    test('string with control characters', () {
      expectUnchangedYamlAfterLoading('a string \n\r');
    });

    test('string with hex escapess', () {
      expectUnchangedYamlAfterLoading('\\x0d\\x0a is \\r\\n');
    });

    test('flow map', () {
      expectUnchangedYamlAfterLoading('{a: 2}');
    });

    test('flow list', () {
      expectUnchangedYamlAfterLoading('[1, 2]');
    });

    test('flow list with different types of elements', () {
      expectUnchangedYamlAfterLoading('[1, a]');
    });

    test('flow list with weird spaces', () {
      expectUnchangedYamlAfterLoading('[ 1 ,      2]');
    });

    test('multiline string', () {
      expectUnchangedYamlAfterLoading('''
      Mark set a major league
      home run record in 1998.''');
    });

    test('tilde', () {
      expectUnchangedYamlAfterLoading('~');
    });

    test('false', () {
      expectUnchangedYamlAfterLoading('false');
    });

    test('block map', () {
      expectUnchangedYamlAfterLoading('''a: 
    b: 1
    ''');
    });

    test('block list', () {
      expectUnchangedYamlAfterLoading('''a: 
    - 1
    ''');
    });

    test('complicated example', () {
      expectUnchangedYamlAfterLoading('''verb: RecommendCafes
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

  group('updates', () {
    test('simple block map', () {
      var doc = YamlEditBuilder("YAML: YAML Ain't Markup Language");
      doc.setIn(['YAML'], 'hi');

      expect(doc.toString(), equals('YAML: hi'));
    });

    test('simple block map with comment', () {
      var doc = YamlEditBuilder("YAML: YAML Ain't Markup Language # comment");
      doc.setIn(['YAML'], 'hi');

      expect(doc.toString(), equals('YAML: hi # comment'));
    });

    test('simple flow map', () {
      var doc = YamlEditBuilder("{YAML: YAML Ain't Markup Language}");
      doc.setIn(['YAML'], 'hi');

      expect(doc.toString(), equals('{YAML: hi}'));
    });

    test('simple flow map with spacing', () {
      var doc = YamlEditBuilder("{YAML:  YAML Ain't Markup Language }");
      doc.setIn(['YAML'], 'hi');

      expect(doc.toString(), equals('{YAML:  hi}'));
    });

    test('simple flow map with spacing (2)', () {
      var doc = YamlEditBuilder(
          "{ YAML:  YAML Ain't Markup Language , XML: Extensible Markup Language , HTML: Hypertext Markup Language }");
      doc.setIn(['XML'], 'XML Markup Language');

      expect(
          doc.toString(),
          equals(
              "{ YAML:  YAML Ain't Markup Language , XML: XML Markup Language, HTML: Hypertext Markup Language }"));
    });

    test('simple block list', () {
      var doc = YamlEditBuilder("- YAML Ain't Markup Language");
      doc.setIn([0], 'hi');

      expect(doc.toString(), equals('- hi'));
    });

    test('simple block list with comment', () {
      var doc = YamlEditBuilder("- YAML Ain't Markup Language # comment");
      doc.setIn([0], 'hi');

      expect(doc.toString(), equals('- hi # comment'));
    });

    test('simple block list with comment and spaces', () {
      var doc = YamlEditBuilder("-  YAML Ain't Markup Language  # comment");
      doc.setIn([0], 'hi');

      expect(doc.toString(), equals('-  hi  # comment'));
    });

    test('simple flow list', () {
      var doc = YamlEditBuilder("[YAML Ain't Markup Language]");
      doc.setIn([0], 'hi');

      expect(doc.toString(), equals('[hi]'));
    });

    test('simple flow list with spacing', () {
      var doc = YamlEditBuilder("[ YAML Ain't Markup Language ]");
      doc.setIn([0], 'hi');

      expect(doc.toString(), equals('[ hi]'));
    });

    test('simple flow list with spacing (2)', () {
      var doc = YamlEditBuilder('[ 0 , 1 , 2 , 3 ]');
      doc.setIn([1], 4);

      expect(doc.toString(), equals('[ 0 , 4, 2 , 3 ]'));
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
    });

    test('nested block map', () {
      var doc = YamlEditBuilder('''
a: 1
b: 2
c: 
  d: 4
''');
      doc.setIn(['c', 'e'], 5);
      expect(doc.toString(), equals('''
a: 1
b: 2
c: 
  d: 4
  e: 5
'''));
    });

    test('simple flow map', () {
      var doc = YamlEditBuilder('{a: 1, b: 2}');
      doc.setIn(['c'], 3);
      expect(doc.toString(), equals('{a: 1, b: 2, c: 3}'));
    });

    test('empty flow map ', () {
      var doc = YamlEditBuilder('{}');
      doc.setIn(['a'], 1);
      expect(doc.toString(), equals('{a: 1}'));
    });
  });

  group('removeIn', () {
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
    });

    test('simple flow list', () {
      var doc = YamlEditBuilder('[1, 2, 3]');
      doc.removeIn([1]);
      expect(doc.toString(), equals('[1, 3]'));
    });

    test('simple flow list (2)', () {
      var doc = YamlEditBuilder('[1, "b", "c"]');
      doc.removeIn([1]);
      expect(doc.toString(), equals('[1, "c"]'));
    });

    test('simple flow list (3)', () {
      var doc = YamlEditBuilder('[1, {a: 1}, "c"]');
      doc.removeIn([1]);
      expect(doc.toString(), equals('[1, "c"]'));
    });
  });

//   group('remove', () {
//     test('simple block list ', () {
//       var doc = YamlEditBuilder('''
// - 0
// - 1
// - 2
// - 3
// ''');
//       doc.removeIn([1]);
//       expect(doc.toString(), equals('''
// - 0
// - 2
// - 3
// '''));
//     });

//     test('simple flow list ', () {
//       var doc = YamlEditBuilder('[1, 2, 3]');
//       doc.removeIn([2]);
//       expect(doc.toString(), equals('[1, 3]'));
//     });

//     test('simple flow list (2)', () {
//       var doc = YamlEditBuilder('[1, 2, 3]');
//       doc.removeIn([3]);
//       expect(doc.toString(), equals('[1, 2]'));
//     });

//     test('simple flow list (3)', () {
//       var doc = YamlEditBuilder('[1, 2, 3]');
//       doc.removeIn([1]);
//       expect(doc.toString(), equals('[ 2, 3]'));
//     });

//     test('simple flow list (4)', () {
//       var doc = YamlEditBuilder('[1, 2, 3]');
//       doc.removeIn([4]);
//       expect(doc.toString(), equals('[1, 2, 3]'));
//     });

//     test('simple block map', () {
//       var doc = YamlEditBuilder('''
// a: 1
// b: 2
// c: 3
// ''');
//       doc.removeIn(['b']);
//       expect(doc.toString(), equals('''
// a: 1
// c: 3
// '''));
//     });

//     test('simple flow map ', () {
//       var doc = YamlEditBuilder('{a: 1, b: 2, c: 3}');
//       doc.removeIn(['b']);
//       expect(doc.toString(), equals('{a: 1, c: 3}'));
//     });
//   });

  group('add', () {
    test('simple block list ', () {
      var doc = YamlEditBuilder('''
- 0
- 1
- 2
- 3
''');
      doc.addIn([], 4);
      expect(doc.toString(), equals('''
- 0
- 1
- 2
- 3
- 4
'''));
    });

    test('list to simple block list ', () {
      var doc = YamlEditBuilder('''
- 0
- 1
- 2
- 3
''');
      doc.addIn([], [4, 5, 6]);
      expect(doc.toString(), equals('''
- 0
- 1
- 2
- 3
- - 4
  - 5
  - 6
'''));
    });

    test('nested block list ', () {
      var doc = YamlEditBuilder('''
- 0
- - 1
  - 2
''');
      doc.addIn([1], 3);
      expect(doc.toString(), equals('''
- 0
- - 1
  - 2
  - 3
'''));
    });

    test('block list to nested block list ', () {
      var doc = YamlEditBuilder('''
- 0
- - 1
  - 2
''');
      doc.addIn([1], [3, 4, 5]);

      expect(doc.toString(), equals('''
- 0
- - 1
  - 2
  - - 3
    - 4
    - 5
'''));
    });

    test('simple flow list ', () {
      var doc = YamlEditBuilder('[0, 1, 2]');
      doc.addIn([], 3);
      expect(doc.toString(), equals('[0, 1, 2, 3]'));
    });

    test('empty flow list ', () {
      var doc = YamlEditBuilder('[]');
      doc.addIn([], 0);
      expect(doc.toString(), equals('[0]'));
    });
  });
}
