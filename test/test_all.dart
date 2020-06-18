import 'package:test/test.dart';

import 'editor_test.dart' as editor;
import 'golden_test.dart' as golden;
import 'source_edit_test.dart' as source;
import 'wrap_test.dart' as wrap;
import 'utils_test.dart' as utils;

void main() async {
  await golden.main();
  group('editor', editor.main);
  group('source_edit', source.main);
  group('wrap', wrap.main);
  group('utils', utils.main);
}
