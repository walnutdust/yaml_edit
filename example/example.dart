import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

void main() {
  final doc = YamlEditor('''
- >
    folded string
''');
  doc.assign(
      [0], wrapAsYamlNode('test\ntest\n\n', scalarStyle: ScalarStyle.FOLDED));

  print(doc);
}
