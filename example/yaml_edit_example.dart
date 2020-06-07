import 'package:yaml_edit/yaml_edit.dart';

void main() {
  var yamlEditBuilder = YamlEditBuilder('{YAML: YAML}');
  yamlEditBuilder.setIn(['YAML'], "YAML Ain't Markup Language");
  print(yamlEditBuilder);
}
