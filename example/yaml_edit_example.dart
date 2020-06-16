import 'package:yaml_edit/yaml_edit.dart';

void main() {
  final doc2 = YamlEditor('''
     - 0
     - 1 # comment
     - 2
  ''');
  doc2.remove([1]);
  doc2.insertIntoList([], 1, 'test');
  print(doc2);
}
