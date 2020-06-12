import 'package:test/test.dart';

import 'editor_test.dart' as editor;
import 'golden_test.dart' as golden;
import 'source_edit_test.dart' as source;

void main() async {
  group('editor', editor.main);
  group('golden', () => golden.main);
  group('source_edit', source.main);
}
