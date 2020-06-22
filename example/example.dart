import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

void main() {
  final doc = YamlEditor('{a: 4, b: [4, 5]}');

  print((doc.parseAt(['b']) as dynamic).span);
  print(doc);
}
