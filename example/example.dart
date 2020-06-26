import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

void main() {
  final yamlEditor = YamlEditor('YAML: YAML');
  yamlEditor.assign(['YAML'], "YAML Ain't Markup Language");
  yamlEditor.assign(['XML'], 'Extensible Markup Language');
  print(yamlEditor);
}
