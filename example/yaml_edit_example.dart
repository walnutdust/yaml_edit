import 'package:yaml_edit/yaml_edit.dart';

void main() {
  final doc = YamlEditor('''
- 0
- {a: 1, b: 2}
- 2
- 3
''');
  doc.assign([1], 4);
  print(doc);
}
