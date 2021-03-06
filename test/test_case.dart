import 'dart:io';

import 'package:yaml_edit/yaml_edit.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'test_utils.dart';

/// Interface for creating golden Test cases
class TestCases {
  final List<TestCase> testCases;

  /// Creates a [TestCases] object based on test directory and golden directory
  /// path.
  static Future<TestCases> getTestCases(Uri testDirUri, Uri goldDirUri) async {
    var testDir = Directory.fromUri(testDirUri);
    var testCaseList = [];

    if (testDir.existsSync()) {
      /// Recursively grab all the files in the testing directory.
      var entityStream = testDir.list(recursive: true, followLinks: false);
      entityStream =
          entityStream.where((entity) => entity.path.endsWith('.test'));

      var testCasesPathStream = entityStream.map((entity) => entity.uri);
      var testCasePaths = await testCasesPathStream.toList();

      testCaseList = testCasePaths.map((inputUri) {
        var inputName = inputUri.toFilePath(windows: false).split('/').last;
        var inputNameWithoutExt = inputName.substring(0, inputName.length - 5);
        var goldenUri = goldDirUri.resolve('./$inputNameWithoutExt.golden');

        return TestCase(inputUri, goldenUri);
      }).toList();
    }

    return TestCases(testCaseList);
  }

  /// Tests all the [TestCase]s if the golden files exist, create the golden
  /// files otherwise.
  void test() {
    var tested = 0;
    var created = 0;

    for (var testCase in testCases) {
      testCase.testOrCreate();
      if (testCase.state == TestCaseStates.testedGoldenFile) {
        tested++;
      } else if (testCase.state == TestCaseStates.createdGoldenFile) {
        created++;
      }
    }

    print(
        'Successfully tested $tested inputs against golden files, created $created golden files');
  }

  TestCases(this.testCases);

  int get length => testCases.length;
}

/// Enum representing the different states of [TestCase]s.
enum TestCaseStates { initialized, createdGoldenFile, testedGoldenFile }

/// Interface for a golden test case. Handles the logic for test conduct/golden
/// test update accordingly.
class TestCase {
  final Uri inputUri;
  final Uri goldenUri;
  final List<String> states = [];

  String info;
  YamlEditor yamlBuilder;
  List<YamlModification> modifications;

  String inputLineEndings = '\n';

  TestCaseStates state = TestCaseStates.initialized;

  TestCase(this.inputUri, this.goldenUri) {
    var inputFile = File.fromUri(inputUri);
    if (!inputFile.existsSync()) {
      throw Exception('Input File does not exist!');
    }

    _initialize(inputFile);
  }

  /// Initializes the [TestCase] by reading the corresponding [inputFile] and
  /// parsing the different portions, and then running the input yaml against
  /// the specified modifications.
  ///
  /// Precondition: [inputFile] must exist, and inputs must be well-formatted.
  void _initialize(File inputFile) {
    var input = inputFile.readAsStringSync();

    inputLineEndings = detectWindowsLineEndings(input) ? '\r\n' : '\n';
    var inputElements = input.split('---$inputLineEndings');

    if (inputElements.length != 3) {
      throw AssertionError('File ${inputFile.path} is not properly formatted.');
    }

    info = inputElements[0];
    yamlBuilder = YamlEditor(inputElements[1]);
    var rawModifications = getValueFromYamlNode(loadYaml(inputElements[2]));
    modifications = parseModifications(rawModifications);

    /// Adds the initial state as well, so we can check that the simplest
    /// parse -> immediately dump does not affect the string.
    states.add(yamlBuilder.toString());

    _performModifications();
  }

  void _performModifications() {
    for (var mod in modifications) {
      _performModification(mod);
      states.add(yamlBuilder.toString());
    }
  }

  void _performModification(YamlModification mod) {
    switch (mod.method) {
      case YamlModificationMethod.update:
        yamlBuilder.update(mod.path, mod.value);
        return;
      case YamlModificationMethod.remove:
        yamlBuilder.remove(mod.path);
        return;
      case YamlModificationMethod.appendTo:
        yamlBuilder.appendToList(mod.path, mod.value);
        return;
      case YamlModificationMethod.prependTo:
        yamlBuilder.prependToList(mod.path, mod.value);
        return;
      case YamlModificationMethod.insert:
        yamlBuilder.insertIntoList(mod.path, mod.index, mod.value);
        return;
      case YamlModificationMethod.splice:
        yamlBuilder.spliceList(mod.path, mod.index, mod.deleteCount, mod.value);
        return;
    }
  }

  void testOrCreate() {
    var goldenFile = File.fromUri(goldenUri);
    if (!goldenFile.existsSync()) {
      createGoldenFile(goldenFile);
    } else {
      testGoldenFile(goldenFile);
    }
  }

  void createGoldenFile(File goldenFile) {
    /// Assumes user wants the golden file to have the same line endings as
    /// the input file.
    final goldenOutput = states.join('---$inputLineEndings');

    goldenFile.writeAsStringSync(goldenOutput);
    state = TestCaseStates.createdGoldenFile;
  }

  /// Tests the golden file. Ensures that the number of states are the same, and
  /// that the individual states are the same.
  void testGoldenFile(File goldenFile) {
    var inputFileName = inputUri.toFilePath(windows: false).split('/').last;
    List<String> goldenStates;
    var golden = goldenFile.readAsStringSync();

    if (detectWindowsLineEndings(golden)) {
      goldenStates = golden.split('---\r\n');
    } else {
      goldenStates = golden.split('---\n');
    }

    group('testing $inputFileName - input and golden files have', () {
      test('same number of states', () {
        expect(states.length, equals(goldenStates.length));
      });

      for (var i = 0; i < states.length; i++) {
        test('same state $i', () {
          expect(states[i], equals(goldenStates[i]));
        });
      }
    });

    state = TestCaseStates.testedGoldenFile;
  }
}

/// Converts a [YamlList] into a Dart list.
List getValueFromYamlList(YamlList node) {
  return node.value.map((n) {
    if (n is YamlNode) return getValueFromYamlNode(n);
    return n;
  }).toList();
}

/// Converts a [YamlMap] into a Dart Map.
Map getValueFromYamlMap(YamlMap node) {
  var keys = node.keys;
  var result = {};
  for (var key in keys) {
    result[key.value] = result[key].value;
  }

  return result;
}

/// Converts a [YamlNode] into a Dart object.
dynamic getValueFromYamlNode(YamlNode node) {
  switch (node.runtimeType) {
    case YamlList:
      return getValueFromYamlList(node);
    case YamlMap:
      return getValueFromYamlMap(node);
    default:
      return node.value;
  }
}

/// Converts the list of modifications from the raw input to [YamlModification]
/// objects.
List<YamlModification> parseModifications(List<dynamic> modifications) {
  return modifications.map((mod) {
    Object value;
    int index;
    int deleteCount;
    final method = getModificationMethod(mod[0] as String);

    final path = mod[1] as List;

    if (method == YamlModificationMethod.appendTo ||
        method == YamlModificationMethod.update ||
        method == YamlModificationMethod.prependTo) {
      value = mod[2];
    } else if (method == YamlModificationMethod.insert) {
      index = mod[2];
      value = mod[3];
    } else if (method == YamlModificationMethod.splice) {
      index = mod[2];
      deleteCount = mod[3];

      if (mod[4] is! List) {
        throw ArgumentError('Invalid array ${mod[4]} used in splice');
      }

      value = mod[4];
    }

    return YamlModification(method, path, index, value, deleteCount);
  }).toList();
}

/// Gets the YAML modification method corresponding to [method]
YamlModificationMethod getModificationMethod(String method) {
  switch (method) {
    case 'update':
      return YamlModificationMethod.update;
    case 'remove':
      return YamlModificationMethod.remove;
    case 'append':
    case 'appendTo':
      return YamlModificationMethod.appendTo;
    case 'prepend':
    case 'prependTo':
      return YamlModificationMethod.prependTo;
    case 'insert':
    case 'insertIn':
      return YamlModificationMethod.insert;
    case 'splice':
      return YamlModificationMethod.splice;
    default:
      throw Exception('$method not recognized!');
  }
}

/// Class representing an abstract YAML modification to be performed
class YamlModification {
  final YamlModificationMethod method;
  final List<dynamic> path;
  final int index;
  final dynamic value;
  final int deleteCount;

  YamlModification(
      this.method, this.path, this.index, this.value, this.deleteCount);

  @override
  String toString() =>
      'method: $method, path: $path, index: $index, value: $value, deleteCount: $deleteCount';
}

/// Returns `true` if the [text] looks like it uses windows line endings.
///
/// The heuristic used is to count all `\n` in the text and if stricly more than
/// half of them are preceded by `\r` we report `true`.
bool detectWindowsLineEndings(String text) {
  var index = -1;
  var unixNewlines = 0;
  var windowsNewlines = 0;
  while ((index = text.indexOf('\n', index + 1)) != -1) {
    if (index != 0 && text[index - 1] == '\r') {
      windowsNewlines++;
    } else {
      unixNewlines++;
    }
  }
  return windowsNewlines > unixNewlines;
}
