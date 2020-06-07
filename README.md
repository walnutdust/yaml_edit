A library for [YAML](www.yaml.org) manipulation

## Usage

A simple usage example:

```dart
import 'package:yaml_edit/yaml_edit.dart';

void main() {
  var yamlEditBuilder = YamlEditBuilder('{YAML: YAML}');
  yamlEditBuilder.setIn(['YAML'], "YAML Ain't Markup Language");
  print(yamlEditBuilder);
  /// Expected output:
  /// {YAML: YAML Ain't Markup Language}
}
```

## Testing

Testing is done in two strategies: Unit testing ([here](./test/mod_test.dart)) and
Golden testing ([here](./test/mod_test_cases.dart)).

With Golden Testing, we define the test parameters, and compare it against output
formed by previous iterations. Input files are found [here](./test/test_cases) and
have the format:

```
INFORMATION (e.g. description) - parsed as text
---
INPUT - parsed as YAML
---
Modifications - parsed as YAML, must be a list.
```

The valid list of modifications are:

- set [path] newValue
- remove [path] newValue
- add [path] newValue

These tests are automatically run with `pub run test`. If a new test file is added,
the test command wil automatically generate the golden file.

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/walnutdust/yaml_edit/issues
