import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

void main() {
  final doc = YamlEditor('''
- 0 # comment 0
# comment A
- 1 # comment 1
# comment B
- 2 # comment 2
''');
  doc.remove([1]);

  print(doc);
}
