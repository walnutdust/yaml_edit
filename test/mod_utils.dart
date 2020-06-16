import 'package:test/test.dart';
import 'package:yaml_edit/src/utils.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Asserts that a string containing a single YAML document is unchanged
/// when dumped right after loading.
Function() expectLoadPreservesYAML(String source) {
  var doc = YamlEditor(source);
  return () => expect(doc.toString(), equals(source));
}

/// Asserts that [builder] has the same internal value as [value].
void expectYamlBuilderValue(YamlEditor builder, dynamic value) {
  var builderValue = builder.parseAt([]);

  if (!deepEquals(value, builderValue.value)) {
    print(deepEquals([1, 2, 3], [1, 2, 3]));
    print(value[[1, 2, 3]]);
    print((builderValue as dynamic)[[1, 2, 3]]);
  }

  expect(
      builderValue, predicate((actual) => deepEquals(actual, value), '$value'));
}
