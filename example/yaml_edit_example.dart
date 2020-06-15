import 'package:yaml_edit/yaml_edit.dart';

void main() {
  final doc = YamlEditor('''
hi

uh










uhmn''');

  print(doc);
  print(doc.parseAt([]));
}
