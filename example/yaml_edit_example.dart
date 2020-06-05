import 'package:yaml_edit/yaml_edit.dart';

void main() {
  var doc = YamlEditBuilder('''
name: yaml # comment
version: 2.2.1-dev # comment

description: A parser for YAML, a human-friendly data serialization standard
homepage: https://github.com/dart-lang/yaml

environment:
  sdk: '>=2.4.0 <3.0.0'

dependencies: # list of dependencies

  charcode: ^1.1.0 # charcode dependency
  collection: '>=1.1.0 <2.0.0'

  # comment

  string_scanner: '>=0.1.4 <2.0.0'
  source_span: '>=1.0.0 <2.0.0'
  indent: ^1.0.0+2 # indent dependency

# This is a list of dev dependencies
dev_dependencies:
  pedantic: ^1.0.0
  path: '>=1.2.0 <2.0.0'
  test: '>=0.12.0 <2.0.0'
''');
  print(doc);
}
