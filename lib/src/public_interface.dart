import 'package:yaml/yaml.dart';

import './source_edit.dart';

/// An interface for modififying [YAML][1] documents while preserving comments and
/// whitespaces.
///
/// YAML parsing is supported by `package:yaml`, and modifications are performed as
/// string operations. Each time a modification takes place via one of the public
/// methods, we calculate the expected final result, and parse the result YAML string,
/// and ensure the two YAML trees match. Users may define the default settings to be
/// applied to these string modifications. Note however that these settings only apply
/// to portions of the YAML that are modified by this class.
///
/// [1]: https://yaml.org/
abstract class YamlEditBuilder {
  /// The configuration to be used for the various string manipulation operations.
  final YamlEditBuilderConfig config;

  /// Returns a list of [SourceEdit]s detailing the string modifications that have
  /// been made. Intended to be compatible with `package:analysis_server`.
  List<SourceEdit> get edits;

  YamlEditBuilder(String yaml, {this.config = const YamlEditBuilderConfig()});

  /// Returns the current YAML string after the various modifications.
  @override
  String toString();

  /// Returns the [YamlNode] present at the path.
  YamlNode parseValueAt(Iterable<Object> path);

  /// Sets [value] in the [path]. If the [path] is not accessible (e.g. it currently
  /// does not exist in the document), an error will be thrown.
  void setIn(Iterable<Object> path, Object value);

  /// Removes the value in the path.
  void removeIn(Iterable<Object> path);

  /// Appends [value] into the list at [listPath], only if the element at the given path
  /// is a List.
  void addInList(Iterable<Object> listPath, Object value);

  /// Prepends [value] into the list at [listPath], only if the element at the given path
  /// is a List.
  void prependInList(Iterable<Object> listPath, Object value);

  /// Inserts [value] into the list at [listPath], only if the element at the given path
  /// is a list. [index] must be non-negative and no greater than the list's length.
  void insertInList(Iterable<Object> listPath, int index, Object value);

  /// Checks if [value] is contained in a list at [listPath].
  bool containsValueInList(Iterable<Object> listPath, Object value);

  /// Checks if a given [path] exists in the YAML.
  bool pathExists(Iterable<Object> path);
}

/// Configuration settings for [YamlEditBuilder].
class YamlEditBuilderConfig {
  /// The number of additional spaces from the starting column between block YAML elements
  /// of adjacent levels.
  final int indentationStep;

  /// Enforce flow structures when adding or modifying values. If this value is false,
  /// we try to make collections in block style where possible.
  final bool enforceFlow;

  const YamlEditBuilderConfig(
      {this.indentationStep = 2, this.enforceFlow = false});
}
