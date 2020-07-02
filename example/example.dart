import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

void main() {
  final doc = YamlEditor('''
a:
 - b
 - - c
   - d
''');
  doc.prependToList(
      ['a'], wrapAsYamlNode({1: 2}, collectionStyle: CollectionStyle.FLOW));

  print(doc);
}
