import 'dart:collection' as collection;
import 'package:collection/collection.dart';
import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

import 'equality.dart';

/// Wraps [value] into a [YamlNode].
YamlNode yamlNodeFrom(Object value,
    {CollectionStyle collectionStyle = CollectionStyle.ANY,
    ScalarStyle scalarStyle = ScalarStyle.ANY}) {
  if (value is YamlNode) {
    return value;
  } else if (value is Map) {
    return YamlMapWrap(value, collectionStyle: collectionStyle);
  } else if (value is List) {
    return YamlListWrap(value, collectionStyle: collectionStyle);
  } else {
    return YamlScalarWrap(value, style: scalarStyle);
  }
}

/// Checks if [index] is [int], >=0, < [length]
bool isValidIndex(Object index, int length) {
  return index is int && index >= 0 && index < length;
}

/// Internal class that allows us to define a constructor on [YamlScalar]
/// which takes in [style] as an argument.
class YamlScalarWrap implements YamlScalar {
  /// The [ScalarStyle] to be used for the scalar.
  @override
  final ScalarStyle style;

  @override
  final SourceSpan span = null;

  @override
  final dynamic value;

  YamlScalarWrap(this.value, {this.style = ScalarStyle.ANY}) {
    ArgumentError.checkNotNull(style, 'scalarStyle');
  }

  @override
  String toString() => value.toString();
}

/// Internal class that allows us to define a constructor on [YamlMap]
/// which takes in [style] as an argument.
class YamlMapWrap
    with collection.MapMixin, UnmodifiableMapMixin
    implements YamlMap {
  /// The [CollectionStyle] to be used for the map.
  @override
  final CollectionStyle style;

  @override
  final Map<dynamic, YamlNode> nodes;

  @override
  final SourceSpan span = null;

  factory YamlMapWrap(Map dartMap,
      {CollectionStyle collectionStyle = CollectionStyle.ANY}) {
    ArgumentError.checkNotNull(collectionStyle, 'collectionStyle');

    var wrappedMap = deepEqualsMap<dynamic, YamlNode>();

    for (var entry in dartMap.entries) {
      var wrappedKey = yamlNodeFrom(entry.key);
      var wrappedValue = yamlNodeFrom(entry.value);
      wrappedMap[wrappedKey] = wrappedValue;
    }
    return YamlMapWrap._(wrappedMap, style: collectionStyle);
  }

  YamlMapWrap._(this.nodes, {this.style = CollectionStyle.ANY});

  @override
  dynamic operator [](Object key) => nodes[key]?.value;

  @override
  Iterable get keys => nodes.keys.map((node) => node.value);

  @override
  Map get value => this;
}

/// Internal class that allows us to define a constructor on [YamlList]
/// which takes in [style] as an argument.
class YamlListWrap with collection.ListMixin implements YamlList {
  /// The [CollectionStyle] to be used for the list.
  @override
  final CollectionStyle style;

  @override
  final List<YamlNode> nodes;

  @override
  final SourceSpan span = null;

  @override
  int get length => nodes.length;

  @override
  set length(int index) {
    throw UnsupportedError('Cannot modify an unmodifiable List');
  }

  factory YamlListWrap(List dartList,
      {CollectionStyle collectionStyle = CollectionStyle.ANY}) {
    ArgumentError.checkNotNull(collectionStyle, 'collectionStyle');

    final wrappedList = dartList.map((v) => yamlNodeFrom(v)).toList();
    return YamlListWrap._(wrappedList, style: collectionStyle);
  }

  YamlListWrap._(this.nodes, {this.style = CollectionStyle.ANY});

  @override
  dynamic operator [](int index) => nodes[index].value;

  @override
  operator []=(int index, value) {
    throw UnsupportedError('Cannot modify an unmodifiable List');
  }

  @override
  List get value => this;
}
