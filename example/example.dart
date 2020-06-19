import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

void main() {
  final doc = YamlEditor('{no: "no"}');
  print(doc);
  doc.assign(['no'], 'a string');
  print(doc);
  doc.assign([false], '"boolean false"');
  print(doc);
}
