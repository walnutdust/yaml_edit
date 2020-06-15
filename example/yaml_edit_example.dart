import 'package:yaml_edit/yaml_edit.dart';

void main() {
  final doc = YamlEditor("- YAML Ain't Markup Language");
  doc.assign([], 0, [1, 2]);
}
