import 'dart:io';
import 'dart:isolate';

import './test_case.dart';

/// This script performs snapshot testing of the inputs in the testing directory
/// against golden files if they exist, and creates the golden files otherwise.
///
/// Input directory should be in `test/test_cases`, while the golden files should
/// be in `test/test_cases_golden`.
///
/// For more information on the expected input and output, refer to the README
/// in the testdata folder
Future<void> main() async {
  final packageUri = await Isolate.resolvePackageUri(
      Uri.parse('package:yaml_edit/yaml_edit.dart'));

  final testdataUri = packageUri.resolve('../test/testdata/');
  final inputDirectory = Directory.fromUri(testdataUri.resolve('input/'));
  final goldDirectoryUri = testdataUri.resolve('output/');

  if (!inputDirectory.existsSync()) {
    throw ('Testing Directory does not exist!');
  }

  final testCases =
      await TestCases.getTestCases(inputDirectory.uri, goldDirectoryUri);

  testCases.test();
}
