import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

void main() {
  final doc = loadYamlNode('> hi');
  print(doc.runtimeType);
}
