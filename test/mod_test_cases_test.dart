import 'dart:io';

import 'package:path/path.dart' show dirname;
import './test_case.dart';

/// This script performs snapshot testing of the inputs in the testing directory
/// against golden files if they exist, and creates the golden files otherwise.
///
/// Input directory should be in `test/test_cases`, while the golden files should
/// be in `test/test_cases_golden`.
///
/// For more information on the expected input and output, refer to the README
void main() async {
  var scriptPath = getScriptPath();
  var testDirectory = Directory('$scriptPath/test_cases');
  var goldDirectory = Directory('$scriptPath/test_cases_golden');

  if (!testDirectory.existsSync()) {
    throw ('Testing Directory does not exist!');
  }

  var testCases =
      await TestCases.getTestCases(testDirectory.path, goldDirectory.path);

  testCases.test();
}

/// Helper method to return the directory of this file.
String getScriptPath() {
  var fullScriptPath = dirname(Platform.script.path);
  var scriptPathBeginIndex = fullScriptPath.indexOf('file://');
  if (scriptPathBeginIndex == -1) {
    scriptPathBeginIndex = 0;
  } else {
    scriptPathBeginIndex += 'file://'.length;
  }

  return fullScriptPath.substring(scriptPathBeginIndex);
}
