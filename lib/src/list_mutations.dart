import 'package:yaml/yaml.dart';

import 'source_edit.dart';
import 'strings.dart';
import 'utils.dart';

/// Returns a [SourceEdit] describing the change to be made on [yaml] to achieve the
/// effect of setting the element at [index] to [newValue] when re-parsed.
SourceEdit assignInList(
    String yaml, YamlList list, int index, Object newValue) {
  final currValue = list.nodes[index];
  final offset = currValue.span.start.offset;
  var valueString;

  /// We do not use [_formatNewBlock] since we want to only replace the contents
  /// of this node while preserving comments/whitespace, while [_formatNewBlock]
  /// produces a string represnetation of a new node.
  if (list.style == CollectionStyle.BLOCK) {
    final indentation =
        getListIndentation(yaml, list) + detectIndentation(yaml);
    valueString = getBlockString(newValue, indentation);
  } else {
    valueString = getFlowString(newValue);
  }

  return SourceEdit(offset, currValue.span.length, valueString);
}

/// Returns a [SourceEdit] describing the change to be made on [yaml] to achieve the
/// effect of appending [elem] to the list.
SourceEdit appendIntoList(String yaml, YamlList list, Object elem) {
  if (list.style == CollectionStyle.FLOW) {
    return _appendToFlowList(yaml, list, elem);
  } else {
    return _appendToBlockList(yaml, list, elem);
  }
}

/// Returns a [SourceEdit] describing the change to be made on [yaml] to achieve the
/// effect of inserting [elem] to the list at [index].
SourceEdit insertInList(String yaml, YamlList list, int index, Object elem) {
  if (index > list.length || index < 0) {
    throw RangeError.range(index, 0, list.length);
  }

  /// We call the append method if the user wants to append it to the end of the list
  /// because appending requires different techniques.
  if (index == list.length) {
    return appendIntoList(yaml, list, elem);
  } else {
    if (list.style == CollectionStyle.FLOW) {
      return _insertInFlowList(yaml, list, index, elem);
    } else {
      return _insertInBlockList(yaml, list, index, elem);
    }
  }
}

/// Returns a [SourceEdit] describing the change to be made on [yaml] to achieve the
/// effect of removing the element at [index] when re-parsed.
SourceEdit removeInList(String yaml, YamlList list, int index) {
  final nodeToRemove = list.nodes[index];

  if (list.style == CollectionStyle.FLOW) {
    return _removeFromFlowList(yaml, list, nodeToRemove, index);
  } else {
    return _removeFromBlockList(yaml, list, nodeToRemove, index);
  }
}

/// Returns a [SourceEdit] describing the change to be made on [yaml] to achieve the
/// effect of addition [elem] into [nodes], noting that this is a flow list.
SourceEdit _appendToFlowList(String yaml, YamlList list, Object elem) {
  final valueString = _formatNewFlow(list, elem, true);
  return SourceEdit(list.span.end.offset - 1, 0, valueString);
}

/// Returns a [SourceEdit] describing the change to be made on [yaml] to achieve the
/// effect of addition [elem] into [nodes], noting that this is a block list.
SourceEdit _appendToBlockList(String yaml, YamlList list, Object elem) {
  var formattedValue = _formatNewBlock(yaml, list, elem);

  // Adjusts offset to after the trailing newline of the last entry, if it exists
  if (list.isNotEmpty) {
    final lastValueSpanEnd = list.nodes.last.span.end.offset;
    final nextNewLineIndex = yaml.indexOf('\n', lastValueSpanEnd);
    if (nextNewLineIndex == -1) {
      formattedValue = '\n' + formattedValue;
    }
  }

  return SourceEdit(list.span.end.offset, 0, formattedValue);
}

/// Formats [elem] into a new node for block lists.
String _formatNewBlock(String yaml, YamlList list, Object elem) {
  final indentation = getListIndentation(yaml, list) + detectIndentation(yaml);
  final valueString = getBlockString(elem, indentation);
  final indentedHyphen = ' ' * getListIndentation(yaml, list) + '- ';

  return '$indentedHyphen$valueString\n';
}

/// Formats [elem] into a new node for flow lists.
String _formatNewFlow(YamlList list, Object elem, [bool isLast = false]) {
  var valueString = getFlowString(elem);
  if (list.isNotEmpty) {
    if (isLast) valueString = ', $valueString';
    if (!isLast) valueString += ', ';
  }

  return valueString;
}

/// Returns a [SourceEdit] describing the change to be made on [yaml] to achieve the
/// effect of inserting [elem] into [nodes] at [index], noting that this is a block
/// list.
///
/// [index] should be non-negative and less than or equal to [length].
SourceEdit _insertInBlockList(
    String yaml, YamlList list, int index, Object elem) {
  if (index == list.length) return _appendToBlockList(yaml, list, elem);

  final formattedValue = _formatNewBlock(yaml, list, elem);

  final currNode = list.nodes[index];
  final currNodeStart = currNode.span.start.offset;
  final start = yaml.lastIndexOf('\n', currNodeStart) + 1;

  return SourceEdit(start, 0, formattedValue);
}

/// Returns a [SourceEdit] describing the change to be made on [yaml] to achieve the
/// effect of inserting [elem] into [nodes] at [index], noting that this is a flow
/// list.
///
/// [index] should be non-negative and less than or equal to [length].
SourceEdit _insertInFlowList(
    String yaml, YamlList list, int index, Object elem) {
  if (index == list.length) return _appendToFlowList(yaml, list, elem);

  final formattedValue = _formatNewFlow(list, elem);

  final currNode = list.nodes[index];
  final currNodeStart = currNode.span.start.offset;
  var start = yaml.lastIndexOf(RegExp(r',|\['), currNodeStart) + 1;
  if (yaml[start] == ' ') start++;

  return SourceEdit(start, 0, formattedValue);
}

/// Returns a [SourceEdit] describing the change to be made on [yaml] to achieve the
/// effect of removing [nodeToRemove] from [nodes], noting that this is a block list.
///
/// [index] should be non-negative and less than or equal to [length].
SourceEdit _removeFromBlockList(
    String yaml, YamlList list, YamlNode removedNode, int index) {
  /// If we are removing the last element in a block list, convert it into a flow
  /// empty list.
  if (list.length == 1) {
    final start = list.span.start.offset;
    final end = getContentSensitiveEnd(removedNode);

    return SourceEdit(start, end - start, '[]');
  }

  final span = removedNode.span;
  var start = yaml.lastIndexOf('\n', span.start.offset);
  var end = yaml.indexOf('\n', span.end.offset);

  if (start == -1) start = 0;
  if (end == -1) end = yaml.length;

  return SourceEdit(start, end - start, '');
}

/// Returns a [SourceEdit] describing the change to be made on [yaml] to achieve the
/// effect of removing [nodeToRemove] from [nodes], noting that this is a flow list.
///
/// [index] should be non-negative and less than or equal to [length].
SourceEdit _removeFromFlowList(
    String yaml, YamlList list, YamlNode nodeToRemove, int index) {
  final span = nodeToRemove.span;
  var start = span.start.offset;
  var end = span.end.offset;

  if (index == 0) {
    start = yaml.lastIndexOf('[', start) + 1;
    if (index == list.length - 1) {
      end = yaml.indexOf(']', end);
    } else {
      end = yaml.indexOf(',', end) + 1;
    }
  } else {
    start = yaml.lastIndexOf(',', start);
  }

  return SourceEdit(start, end - start, '');
}
