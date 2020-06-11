import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

void main() {
  final doc = YamlEditor('''
  - 0
  - 1 # comment
  - 2
  ''');
  doc.setIn([1], 'test'); // "- test   # comment"
  print(doc);

  final doc2 = YamlEditor('''
  - 0
  - 1 # comment
  - 2
  ''');
  doc2.removeIn([1]);
  doc2.insertInList([], 1, 'test');
  print(doc2);
}
