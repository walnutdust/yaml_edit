import 'package:test/test.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'test_utils.dart';

/// This test suite is a temporary measure until we are able to better handle aliases.
void main() {
  group('list ', () {
    test('removing an alias anchor results in AliasError', () {
      final doc = YamlEditor('''
- &SS Sammy Sosa
- *SS
''');

      expect(() => doc.remove([0]), throwsAliasError);
    });

    test('removing an alias reference results in AliasError', () {
      final doc = YamlEditor('''
- &SS Sammy Sosa
- *SS
''');

      expect(() => doc.remove([1]), throwsAliasError);
    });
  });

  group('map', () {
    test('removing an alias anchor results in AliasError', () {
      final doc = YamlEditor('''
a: &SS Sammy Sosa
b: *SS
''');

      expect(() => doc.remove(['a']), throwsAliasError);
    });

    test('removing an alias reference results in AliasError', () {
      final doc = YamlEditor('''
a: &SS Sammy Sosa
b: *SS
''');

      expect(() => doc.remove(['b']), throwsAliasError);
    });
  });
}
