/// This library provides an interface to programmatically modify [YAML][1]
/// while preserving as much whitespace and comments as possible.
///
/// YAML parsing is supported by `package:yaml`, and each time a change is
/// made, the resulting YAML AST is compared against our expected output
/// with deep equality to ensure that the output conforms to our expectations.
///
/// **Example**
/// ```dart
/// import 'package:yaml_edit/yaml_edit.dart';
///
/// void main() {
///  final yamlEditor = YamlEditor('{YAML: YAML}');
///  yamlEditor.assign(['YAML'], "YAML Ain't Markup Language");
///  print(yamlEditor);
///  // Expected Output:
///  // {YAML: YAML Ain't Markup Language}
/// }
/// ```
///
/// [1]: https://yaml.org/
library yaml_edit;

export 'src/source_edit.dart';
export 'src/editor.dart';
export 'src/wrap.dart';
