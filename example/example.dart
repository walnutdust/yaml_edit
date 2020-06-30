import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

void main() {
  final doc = YamlEditor('''
a:
  - false
''');
  doc.prependToList(
      ['a'], wrapAsYamlNode([1234], collectionStyle: CollectionStyle.FLOW));

  print(doc);
}
