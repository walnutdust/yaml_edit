import 'package:yaml_edit/yaml_edit.dart';

void main() {
  final doc = YamlEditor('''
~: null
false: false
No: No
true: true''');
  doc.assign([], null, 'tilde');
  doc.assign([], false, false);
  doc.assign([], 'No', 'no');
  doc.assign([], true, 'true');

  print(doc);
}
