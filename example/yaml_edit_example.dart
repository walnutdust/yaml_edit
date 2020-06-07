import 'package:yaml_edit/yaml_edit.dart';

void main() {
  var doc = YamlEditBuilder('{a: 1, b: {d: 4, e: 5}, c: 3}');
  doc.removeIn(['b', 'd']);
  print(doc);
}
