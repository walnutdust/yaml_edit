import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

void main() {
  final doc = YamlEditor('''
~: null
false: false
No: No
true: true
''');
  doc.assign(["a!\"\#\$%&'()*+,-./09:;<=>?@AZ[\\]^_`az{|}~"], 'safe');

  print(doc);
}
