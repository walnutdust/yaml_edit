import 'dart:collection' as collection;
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

import 'equality.dart';

// TODO: if value is a yamlnode, should we try applying the style too
/// Wraps [value] into a [YamlNode].
///
/// [Map]s, [List]s and Scalars will be wrapped as [YamlMap]s, [YamlList]s,
/// and [YamlScalar]s respectively. If [collectionStyle]/[scalarStyle] is defined,
/// and [value] is a collection or scalar, the wrapped [YamlNode] will have the
/// respective style, otherwise it defaults to the ANY style.
///
///
///
///
///
///  with [collectionStyle] or [scalarStyle] applied.
/// [value] or its children can be instances of [YamlNode], in which case no further
/// wrapping will be done on them.
YamlNode wrapAsYamlNode(Object value,
    {CollectionStyle collectionStyle = CollectionStyle.ANY,
    ScalarStyle scalarStyle = ScalarStyle.ANY}) {
  if (value is YamlNode) {
    return value;
  } else if (value is Map) {
    ArgumentError.checkNotNull(collectionStyle, 'collectionStyle');
    return YamlMapWrap(value, collectionStyle: collectionStyle);
  } else if (value is List) {
    ArgumentError.checkNotNull(collectionStyle, 'collectionStyle');
    return YamlListWrap(value, collectionStyle: collectionStyle);
  } else {
    ArgumentError.checkNotNull(scalarStyle, 'scalarStyle');
    return YamlScalarWrap(value, style: scalarStyle);
  }
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
      var wrappedKey = wrapAsYamlNode(entry.key);
      var wrappedValue = wrapAsYamlNode(entry.value);
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

    final wrappedList = dartList.map((v) => wrapAsYamlNode(v)).toList();
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
