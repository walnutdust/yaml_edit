import 'package:yaml_edit/yaml_edit.dart';

void main() {
  final doc = YamlEditor('[Jan, March, April, June]');
  doc.spliceList([], 1, 0, ['Feb']); // [Jan, Feb, March, April, June]
  print(doc);
  doc.spliceList([], 4, 1, ['May']); // [Jan, Feb, March, April, May]
  print(doc);
}
