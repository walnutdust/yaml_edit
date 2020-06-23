import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

void main() {
  print('\u1019');
  final doc = YamlEditor('- 0');

  doc.assign([0], '\x00');
  print(doc);
}
