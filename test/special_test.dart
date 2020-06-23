import 'package:test/test.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'test_utils.dart';

void main() {
  test('test if "No" is recognized as false', () {
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

  test('array keys are recognized', () {
    final doc = YamlEditor('{[1,2,3]: a}');
    doc.assign([
      [1, 2, 3]
    ], 'sums to 6');

    expect(doc.toString(), equals('{[1,2,3]: sums to 6}'));
    expectYamlBuilderValue(doc, {
      [1, 2, 3]: 'sums to 6'
    });
  });

  test('map keys are recognized', () {
    final doc = YamlEditor('{{a: 1}: a}');
    doc.assign([
      {'a': 1}
    ], 'sums to 6');

    expect(doc.toString(), equals('{{a: 1}: sums to 6}'));
    expectYamlBuilderValue(doc, {
      {'a': 1}: 'sums to 6'
    });
  });
}
