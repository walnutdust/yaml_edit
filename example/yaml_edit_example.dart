import 'package:yaml_edit/yaml_edit.dart';

void main() {
  var doc = YamlEditBuilder('{}');
  doc.setIn(['a'], 1);
  print(doc);
}
