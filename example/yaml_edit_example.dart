import 'package:yaml_edit/yaml_edit.dart';

void main() {
  final doc = YamlEditor('''
a: 1
b: 
  d: 4
  e: 5
c: 3
''');

  doc.assign(['b', 'e'], [1, 2, 3]);
  doc.assign(['b', 'f'], 6);
  print(doc);
}
