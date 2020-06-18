import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:yaml/yaml.dart';

/// Creates a map that uses our custom [deepEquals] and [deepHashCode] functions
/// to determine equality.
Map<K, V> deepEqualsMap<K, V>() =>
    LinkedHashMap(equals: deepEquals, hashCode: deepHashCode);

/// Compares two [Object]s for deep equality. This implementation differs from
/// `package:yaml`'s deep equality notation by allowing for comparison of non-scalar
/// map keys.
bool deepEquals(obj1, obj2) {
  if (obj1 is YamlNode) obj1 = obj1.value;
  if (obj2 is YamlNode) obj2 = obj2.value;

  if (obj1 is Map && obj2 is Map) {
    return mapDeepEquals(obj1, obj2);
  }

  if (obj1 is List && obj2 is List) {
    return listDeepEquals(obj1, obj2);
  }

  return obj1 == obj2;
}

/// Compares two [List]s for deep equality.
bool listDeepEquals(List list1, List list2) {
  if (list1.length != list2.length) return false;

  for (var i = 0; i < list1.length; i++) {
    if (!deepEquals(list1[i], list2[i])) {
      return false;
    }
  }

  return true;
}

/// Compares two [Map]s for deep equality. Differs from `package:yaml`'s deep
/// equality notation by allowing for comparison of non-scalar map keys.
bool mapDeepEquals(Map map1, Map map2) {
  if (map1.length != map2.length) return false;

  for (var key in map1.keys) {
    if (!containsKey(map2, key)) {
      return false;
    }

    /// Because two keys may be equal by deep equality but using one key on the
    /// other map might not get a hit since they may not be both using our
    /// [deepEqualsMap].
    final key2 = getKey(map2, key);

    if (!deepEquals(map1[key], map2[key2])) {
      return false;
    }
  }

  return true;
}

/// Returns a hashcode for [value] such that structures that are equal by [deepEquals]
/// will have the same hash code.
int deepHashCode(Object value) {
  if (value is Map) {
    var equality = const UnorderedIterableEquality();
    return equality.hash(value.keys.map(deepHashCode)) ^
        equality.hash(value.values.map(deepHashCode));
  } else if (value is Iterable) {
    return const IterableEquality().hash(value.map(deepHashCode));
  } else if (value is YamlScalar) {
    return value.value.hashCode;
  }

  return value.hashCode;
}

/// Returns the [YamlNode] corresponding to the provided [key].
YamlNode getKeyNode(YamlMap map, Object key) {
  return (map.nodes.keys.firstWhere((node) => deepEquals(node, key))
      as YamlNode);
}

/// Returns the key in [map] that is equal to the provided [key] by the notion
/// of deep equality.
Object getKey(Map map, Object key) {
  return map.keys.firstWhere((k) => deepEquals(k, key));
}

/// Checks if [map] has any keys equal to the provided [key] by deep equality.
bool containsKey(Map map, Object key) {
  return map.keys.where((node) => deepEquals(node, key)).isNotEmpty;
}
