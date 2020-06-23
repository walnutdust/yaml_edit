import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

void main() {
  final doc = YamlEditor('strings: strings');
  doc.assign(
      ['strings'],
      wrapAsYamlNode({
        'plain': wrapAsYamlNode('string', scalarStyle: ScalarStyle.PLAIN),
        'folded': wrapAsYamlNode('string', scalarStyle: ScalarStyle.FOLDED),
        'single-quoted':
            wrapAsYamlNode('string', scalarStyle: ScalarStyle.SINGLE_QUOTED),
        'literal': wrapAsYamlNode('string', scalarStyle: ScalarStyle.LITERAL),
        'double-quoted':
            wrapAsYamlNode('string', scalarStyle: ScalarStyle.DOUBLE_QUOTED),
      }));
  print(doc);
}
