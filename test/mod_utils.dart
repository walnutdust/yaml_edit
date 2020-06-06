import 'package:test/test.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Asserts that a string containing a single YAML document is unchanged
/// when dumped right after loading.
void expectUnchangedYamlAfterLoading(String source) {
  var doc = YamlEditBuilder(source);
  expect(doc.toString(), equals(source));
}

/// Asserts that [builder] has the same internal value as [value].
void expectYamlBuilderValue(YamlEditBuilder builder, dynamic value) {
  var builderValue = builder.getValueIn([]);

  // Equals creates a matcher that uses the equality defined in builderValue, so we have
  // to swap the expected/actual around.
  expect(value, equals(builderValue));
}
