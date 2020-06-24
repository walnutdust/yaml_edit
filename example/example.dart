import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

void main() {
  final doc = YamlEditor('');
  doc.assign([], wrapAsYamlNode('test\ntest', scalarStyle: ScalarStyle.FOLDED));

  print(doc);
}
