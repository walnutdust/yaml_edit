import 'package:yaml_edit/yaml_edit.dart';

void main() {
  final doc = YamlEditor('{[1,2,3]: a}');
  doc.assign([
    [1, 2, 3]
  ], 'sums to 6');
  print(doc);
}
