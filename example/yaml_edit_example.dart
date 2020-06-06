import 'package:yaml_edit/yaml_edit.dart';

void main() {
  var doc = YamlEditBuilder('''
a: 1''');
  doc.setIn(['b'], 2);
  print(doc);
}
