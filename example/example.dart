import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

void main() {
  final doc = YamlEditor('''
a:
  c: 1
''');
  doc.assign(
      ['a'], {'f': wrapAsYamlNode(' a', scalarStyle: ScalarStyle.LITERAL)});

  print(doc);
}
