import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

void main() {
  final doc = YamlEditor('''
{a: {{[1] : 2}: 3, b: 2}}
''');

  doc.remove([
    'a',
    {
      [1]: 2
    }
  ]);

  print(doc);
}
