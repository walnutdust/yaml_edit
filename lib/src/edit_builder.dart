import './mod.dart';

/// An interface for performing edits on a YAML document.
///
/// Edits are performed on the YAML document through a user provided path,
/// a List containing the keys/indices.
class YamlEditBuilder {
  ModifiableYAML _contents;

  /// Default constructor, loads the [YamlEditBuilder] from a YAML string.
  /// YAML string must contain only one document.
  YamlEditBuilder(String yaml) {
    _contents = ModifiableYAML(yaml);
  }

  /// Traverses down the provided [path] to the second-last node in the [path].
  dynamic _getToBeforeLast(List<dynamic> path) {
    var current = _contents;
    // Traverse down the path list via indexes because we want to avoid the last
    // key. We cannot use a for-in loop to check the value of the last element
    // because it might be a primitive and repeated as a previous key.
    for (var i = 0; i < path.length - 1; i++) {
      current = current[path[i]];
    }

    return current;
  }

  /// Gets the element represented by the [path].
  dynamic _getElemInPath(List<dynamic> path) {
    if (path.isEmpty) {
      return _contents;
    }
    var current = _getToBeforeLast(path);
    return current[path.last];
  }

  /// Gets the value of the element represented by the [path]. If the element is
  /// null, we return null.
  dynamic getValueIn(List<dynamic> path) {
    var elem = _getElemInPath(path);
    if (elem == null) return null;
    return elem.value;
  }

  /// Sets [value] in the [path]. If the [path] is not accessible (e.g. it currently
  /// does not exist in the document), an error will be thrown.
  void setIn(List<dynamic> path, value) {
    var current = _getToBeforeLast(path);
    var lastNode = path.last;
    current[lastNode] = value;
  }

  /// Appends [value] into the given [path], only if the element at the given path
  /// is a List.
  void addIn(List<dynamic> path, value) {
    var elem = _getElemInPath(path);
    elem.add(value);
  }

  /// Removes the value in the path.
  void removeIn(List<dynamic> path) {
    var current = _getToBeforeLast(path);
    var lastNode = path.last;
    current.remove(lastNode);
  }

  /// Inserts [value] at the element given by the [path] if it doesn't exist,
  /// updates it otherwise.
  void upsertIn(List<dynamic> path, value) {
    if (value is Map) {
      var keys = value.keys.toList();
      for (var key in keys) {
        if (getValueIn(path) == null) {
          setIn([...path], value);
        } else {
          upsertIn([...path, key], value[key]);
        }
      }
    } else {
      setIn(path, value);
    }
  }

  /// Returns the current YAML string
  @override
  String toString() => _contents.toString();
}
