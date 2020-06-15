import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Interface for creating golden Test cases
class TestCases {
  final List<TestCase> testCases;

  /// Creates a [TestCases] object based on test directory and golden directory
  /// path.
  static Future<TestCases> getTestCases(
      String testDirPath, String goldDirPath) async {
    var testDir = Directory(testDirPath);
    var testCaseList = [];

    if (testDir.existsSync()) {
      /// Recursively grab all the files in the testing directory.
      var entityStream = testDir.list(recursive: true, followLinks: false);
      entityStream =
          entityStream.where((entity) => entity.path.endsWith('.test'));

      var testCasesPathStream = entityStream.map((entity) => entity.path);
      var testCasePaths = await testCasesPathStream.toList();

      testCaseList = testCasePaths.map((inputPath) {
        var inputName = inputPath.split('/').last;
        var inputNameWithoutExt = inputName.substring(0, inputName.length - 5);
        var goldenPath = '$goldDirPath/$inputNameWithoutExt.golden';

        return TestCase(inputPath, goldenPath);
      }).toList();
    }

    return TestCases(testCaseList);
  }

  /// Tests all the [TestCase]s if the golden files exist, create the golden
  /// files otherwise.
  void test() {
    var tested = 0;
    var created = 0;

    testCases.forEach((testCase) {
      testCase.testOrCreate();
      if (testCase.state == TestCaseStates.testedGoldenFile) {
        tested++;
      } else if (testCase.state == TestCaseStates.createdGoldenFile) {
        created++;
      }
    });

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
  final String inputPath;
  final String goldenPath;
  final List<String> states = [];

  String info;
  YamlEditor yamlBuilder;
  List<YamlModification> modifications;

  TestCaseStates state = TestCaseStates.initialized;

  TestCase(this.inputPath, this.goldenPath) {
    var inputFile = File(inputPath);
    if (!inputFile.existsSync()) {
      throw Exception('Input File does not exist!');
    }

    initialize(inputFile);
  }

  /// Initializes the [TestCase] by reading the corresponding [inputFile] and parsing
  /// the different portions, and then running the input yaml against the specified
  /// modifications.
  ///
  /// Precondition: [inputFile] must exist.
  void initialize(File inputFile) {
    var input = inputFile.readAsStringSync();
    var inputElements = input.split('\n---\n');

    info = inputElements[0];
    yamlBuilder = YamlEditor(inputElements[1]);
    var rawModifications = getValueFromYamlNode(loadYaml(inputElements[2]));
    modifications = parseModifications(rawModifications);

    /// Adds the initial state as well, so we can check that the simplest
    /// parse -> immediately dump does not affect the string.
    states.add(yamlBuilder.toString());

    performModifications();
  }

  void performModifications() {
    for (var mod in modifications) {
      performModification(mod);
      states.add(yamlBuilder.toString());
    }
  }

  void performModification(YamlModification mod) {
    switch (mod.method) {
      case YamlModificationMethod.assign:
        yamlBuilder.assign(mod.path, mod.value);
        return;
      case YamlModificationMethod.remove:
        yamlBuilder.remove(mod.path);
        return;
      case YamlModificationMethod.appendTo:
        yamlBuilder.appendToList(mod.path, mod.value);
        return;
    }
  }

  void testOrCreate() {
    var goldenFile = File(goldenPath);
    if (!goldenFile.existsSync()) {
      createGoldenFile();
    } else {
      testGoldenFile(goldenFile);
    }
  }

  void createGoldenFile() {
    var goldenOutput = states.join('\n---\n');

    var goldenFile = File(goldenPath);
    goldenFile.writeAsStringSync(goldenOutput);
    state = TestCaseStates.createdGoldenFile;
  }

  /// Tests the golden file. Ensures that the number of states are the same, and
  /// that the individual states are the same.
  void testGoldenFile(File goldenFile) {
    var inputFileName = inputPath.split('/').last;
    var goldenStates = goldenFile.readAsStringSync().split('\n---\n');

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

/// Converts the list of modifications from the raw input to [YamlModification] objects.
List<YamlModification> parseModifications(List<dynamic> modifications) {
  return modifications.map((mod) {
    var value;
    var keyOrIndex;
    final method = getModificationMethod((mod[0] as String));

    final path = mod[1] as List;

    if (method == YamlModificationMethod.appendTo) {
      value = mod[2];
    } else if (method == YamlModificationMethod.assign) {
      value = mod[2];
    }

    return YamlModification(method, path, keyOrIndex, value);
  }).toList();
}

/// Gets the YAML modification method corresponding to [method]
YamlModificationMethod getModificationMethod(String method) {
  switch (method) {
    case 'assign':
      return YamlModificationMethod.assign;
    case 'remove':
      return YamlModificationMethod.remove;
    case 'append':
    case 'appendTo':
      return YamlModificationMethod.appendTo;
    default:
      throw Exception('$method not recognized!');
  }
}

/// Class representing an abstract YAML modification to be performed
class YamlModification {
  final YamlModificationMethod method;
  final List<dynamic> path;
  final dynamic keyOrIndex;
  final dynamic value;

  YamlModification(this.method, this.path, this.keyOrIndex, this.value);

  @override
  String toString() =>
      'method: $method, path: $path, keyOrIndex: $keyOrIndex, value: $value';
}

/// Enum to hold the possible modification methods.
enum YamlModificationMethod { appendTo, assign, remove }
