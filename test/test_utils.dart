import 'package:test/test.dart';
import 'package:yaml_edit/src/utils.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Asserts that a string containing a single YAML document is unchanged
/// when dumped right after loading.
void Function() expectLoadPreservesYAML(String source) {
  final doc = YamlEditor(source);
  return () => expect(doc.toString(), equals(source));
}

/// Asserts that [builder] has the same internal value as [expected].
void expectYamlBuilderValue(YamlEditor builder, Object expected) {
  final builderValue = builder.parseAt([]);
  expectDeepEquals(builderValue, expected);
}

/// Asserts that [builder] has the same internal value as [expected].
void expectDeepEquals(Object actual, Object expected) {
  expect(
      actual, predicate((actual) => deepEquals(actual, expected), '$expected'));
}
