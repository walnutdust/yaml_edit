import 'package:yaml_edit/yaml_edit.dart';

void main() {
  final yamlEditor = YamlEditor('{YAML: YAML}');
  yamlEditor.assign(['YAML'], "YAML Ain't Markup Language");
  print(yamlEditor);
}
