import './mod.dart';

class ModifiableYAML {
  dynamic _contents;

  ModifiableYAML(String yaml) {
    _contents = loadYaml(yaml);
  }

  dynamic _getToBeforeLast(path) {
    var current = _contents;

    if (path is List) {
      // Traverse down the path list via indexes because we want to avoid the last
      // key. We cannot use a for-in loop to check the value of the last element
      // because it might be a primitive and repeated as a previous key.
      for (var i = 0; i < path.length - 1; i++) {
        current = current[path[i]];
      }
    }

    return current;
  }

  dynamic _getLastInPath(path) {
    if (path is List) return path.last;

    return path;
  }

  dynamic _getElemInPath(path) {
    if (path is List && path.isEmpty) {
      return _contents;
    }

    var current = _getToBeforeLast(path);
    var lastNode = _getLastInPath(path);

    return current[lastNode];
  }

  dynamic getValueIn(path) {
    var elem = _getElemInPath(path);
    if (elem == null) return null;
    return elem.value;
  }

  void setIn(path, value) {
    var current = _getToBeforeLast(path);
    var lastNode = _getLastInPath(path);
    current[lastNode] = value;
  }

  void addIn(path, value) {
    var elem = _getElemInPath(path);
    elem.add(value);
  }

  void removeIn(path) {
    var current = _getToBeforeLast(path);
    var lastNode = _getLastInPath(path);
    current.remove(lastNode);
  }

  void upsertIn(path, value) {
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

  @override
  String toString() => _contents.toString();
}
