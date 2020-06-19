import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

void main() {
  final doc = YamlEditor('{a: 4}');
  final path = ['b'];
  print(doc.parseAt(path));
  print(doc);
}
