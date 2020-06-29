import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

void main() {
  final doc = YamlEditor('test: test');
  doc.assign(['test'], []);

  print(doc);
}
