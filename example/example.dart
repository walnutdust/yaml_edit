import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

void main() {
  final doc = YamlEditor('- 0');
  doc.assign(
      [0],
      yamlNodeFrom([
        yamlNodeFrom('plain string', scalarStyle: ScalarStyle.PLAIN),
        yamlNodeFrom('single-quoted string',
            scalarStyle: ScalarStyle.SINGLE_QUOTED),
        yamlNodeFrom('double-quoted string',
            scalarStyle: ScalarStyle.DOUBLE_QUOTED),
        yamlNodeFrom('folded string', scalarStyle: ScalarStyle.FOLDED),
        yamlNodeFrom('literal string', scalarStyle: ScalarStyle.LITERAL),
      ]));
  print(doc);
}
