import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

void main() {
  var doc = YamlEditor('a: 2');
  print(doc.parseValueAt(['a', 'b']));
}
