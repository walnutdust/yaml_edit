import 'package:yaml_edit/yaml_edit.dart';

void main() {
  final doc = YamlEditor('''
a: [1]
b: [3]
''');
  doc.remove(['a', 0]);
  print(doc);
}
