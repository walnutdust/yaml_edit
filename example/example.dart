import 'package:yaml_edit/yaml_edit.dart';
import 'package:yaml/yaml.dart';

void main() {
  final doc = YamlEditor('''
a: 1
''');
  doc.assign(
      ['a'],
      wrapAsYamlNode(
          'C:}DI{IdUjO:0gysArUDUR*jI}3`wGCYA7RxsNbiH(fq=@_=a5*+uFF_;o<.xX',
          scalarStyle: ScalarStyle.LITERAL));

  print(doc);
}
