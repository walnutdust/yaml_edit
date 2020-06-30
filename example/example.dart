import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

void main() {
  final doc = YamlEditor('''
a: [0]
''');
  doc.spliceList(
      ['a'],
      0,
      1,
      [
        {'test': wrapAsYamlNode('a', scalarStyle: ScalarStyle.FOLDED)}
      ]);

  print(doc);
}
