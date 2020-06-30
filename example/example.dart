import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

void main() {
  final doc = YamlEditor('''
a: 
  - - 1
    - 2
  - null
''');
  doc.assign(['a', 0], false);

  print(doc);
}
