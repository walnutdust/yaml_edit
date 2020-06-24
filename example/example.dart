import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

void main() {
  final doc = YamlEditor('''YAML: YAML Ain't Markup Language''');
  doc.assign(['YAML'],
      wrapAsYamlNode([1, 2, 3], collectionStyle: CollectionStyle.FLOW));

  print(doc);
}
