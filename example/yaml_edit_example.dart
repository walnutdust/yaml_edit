import 'package:yaml_edit/yaml_edit.dart';

void main() {
  final doc = YamlEditor('''
a: 1
b: 
  d: 4
  e: [5, 6, 7]
c: 3
''');
  print(doc.parseAt(['b', 'e', 2]));
}
