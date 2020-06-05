import 'package:test/test.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Asserts that a string containing a single YAML document is unchanged
/// when dumped right after loading.
void expectUnchangedYamlAfterLoading(String source) {
  var doc = YamlEditBuilder(source);
  expect(doc.toString(), equals(source));
}
