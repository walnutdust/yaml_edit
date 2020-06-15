import 'package:yaml/yaml.dart';

import './source_edit.dart';
import './style.dart';
import './utils.dart';

/// Performs the string operation on [yaml] to achieve the effect of setting
/// the element at [index] to [newValue] when re-parsed.
SourceEdit setInList(
    String yaml, YamlList list, int index, Object newValue, YamlStyle style) {
  final currValue = list.nodes[index];

  final offset = currValue.span.start.offset;
  final length = currValue.span.end.offset - offset;

  var valueString = getBlockString(
      newValue, getListIndentation(yaml, list) + style.indentationStep);

  if (isCollection(newValue)) valueString = '\n' + valueString;

  return SourceEdit(offset, length, valueString);
}

/// Performs the string operation on [yaml] to achieve the effect of removing
/// the element at [index] when re-parsed.
///
/// Returns the node that is removed.
SourceEdit removeInList(String yaml, YamlList list, int index) {
  final nodeToRemove = list.nodes[index];

  if (list.style == CollectionStyle.FLOW) {
    return removeFromFlowList(yaml, list, nodeToRemove, index);
  } else {
    return removeFromBlockList(yaml, list, nodeToRemove, index);
  }
}

/// Performs the string operation on [yaml] to achieve the effect of
/// removing [elem] when re-parsed.
///
/// Returns `true` if [elem] was successfully found and removed, `false` otherwise.
SourceEdit removeFromList(String yaml, YamlList list, Object elem) {
  var index = list.indexOf(elem);
  if (index == -1) return null;

  return removeInList(yaml, list, index);
}

/// Performs the string operation on [yaml] to achieve the effect of
/// appending [elem] to the list.
SourceEdit addToList(String yaml, YamlList list, Object elem, YamlStyle style) {
  if (list.style == CollectionStyle.FLOW) {
    return addToFlowList(yaml, list, elem, style);
  } else {
    return addToBlockList(yaml, list, elem, style);
  }
}

/// Performs the string operation on [yaml] to achieve a similar effect of
/// inserting [elem] to the list at [index].
SourceEdit insertInList(
    String yaml, YamlList list, int index, Object elem, YamlStyle style) {
  if (index > list.length || index < 0) {
    throw RangeError.range(index, 0, list.length);
  }

  /// We call the add method if the user wants to add it to the end of the list
  /// because appending requires different techniques.
  if (index == list.length) {
    return addToList(yaml, list, elem, style);
  } else if (index == 0) {
    if (list.style == CollectionStyle.FLOW) {
      return prependToFlowList(yaml, list, elem, style);
    } else {
      return prependToBlockList(yaml, list, elem, style);
    }
  } else {
    if (list.style == CollectionStyle.FLOW) {
      return insertInFlowList(yaml, list, index, elem, style);
    } else {
      return insertInBlockList(yaml, list, index, elem, style);
    }
  }
}

/// Gets the indentation level of the list. This is 0 if it is a flow list,
/// but returns the number of spaces before the hyphen of elements for
/// block lists.
int getListIndentation(String yaml, YamlList list) {
  if (list.style == CollectionStyle.FLOW) return 0;

  /// An empty block map doesn't really exist.
  if (list.nodes.isEmpty) {
    throw UnsupportedError('Unable to get indentation for empty block list');
  }

  final lastSpanOffset = list.nodes.last.span.start.offset;
  var lastNewLine = yaml.lastIndexOf('\n', lastSpanOffset);
  final lastHyphen = yaml.lastIndexOf('-', lastSpanOffset);

  if (lastNewLine == -1) return lastHyphen;

  return lastHyphen - lastNewLine - 1;
}

/// Returns a new [YamlList] constructed by applying [update] onto the [nodes]
/// of this [YamlList].
YamlList updatedYamlList(YamlList list, Function(List<YamlNode>) update) {
  final newNodes = [...list.nodes];
  update(newNodes);
  return yamlNodeFrom(newNodes);
}

/// Performs the string operation on [yaml] to achieve the effect of removing
/// [nodeToRemove] from [nodes], noting that this is a flow list.
SourceEdit removeFromFlowList(
    String yaml, YamlList list, YamlNode nodeToRemove, int index) {
  final span = nodeToRemove.span;
  var start = span.start.offset;
  var end = span.end.offset;

  if (index == 0) {
    start = yaml.lastIndexOf('[', start) + 1;
    end = yaml.indexOf(RegExp(r',|]'), end) + 1;
  } else {
    start = yaml.lastIndexOf(',', start);
  }

  return SourceEdit(start, end - start, '');
}

/// Performs the string operation on [yaml] to achieve the effect of removing
/// [nodeToRemove] from [nodes], noting that this is a block list.
SourceEdit removeFromBlockList(
    String yaml, YamlList list, YamlNode removedNode, int index) {
  final span = removedNode.span;
  var start = yaml.lastIndexOf('\n', span.start.offset);
  var end = yaml.indexOf('\n', span.end.offset);

  if (start == -1) start = 0;
  if (end == -1) end = yaml.length;

  return SourceEdit(start, end - start, '');
}

/// Performs the string operation on [yaml] to achieve the effect of prepending
/// [elem] into [nodes], noting that this is a flow list.
SourceEdit prependToFlowList(
    String yaml, YamlList list, Object elem, YamlStyle style) {
  var valueString = getFlowString(elem);
  if (list.nodes.isNotEmpty) valueString = '$valueString, ';

  return SourceEdit(list.span.start.offset + 1, 0, valueString);
}

/// Performs the string operation on [yaml] to achieve the effect of prepending
/// [elem] into [nodes], noting that this is a block list.
SourceEdit prependToBlockList(
    String yaml, YamlList list, Object elem, YamlStyle style) {
  final valueString = getBlockString(
      elem, getListIndentation(yaml, list) + style.indentationStep);
  var formattedValue = ''.padLeft(getListIndentation(yaml, list)) + '- ';

  if (isCollection(elem)) {
    formattedValue += valueString
            .substring(getListIndentation(yaml, list) + style.indentationStep) +
        '\n';
  } else {
    formattedValue += valueString + '\n';
  }

  final startOffset = yaml.lastIndexOf('\n', list.span.start.offset) + 1;

  return SourceEdit(startOffset, 0, formattedValue);
}

/// Performs the string operation on [yaml] to achieve the effect of insertion
/// [elem] into [nodes] at [index], noting that this is a flow list. [index] should
/// be non-negative and less than or equal to [length].
SourceEdit insertInFlowList(
    String yaml, YamlList list, int index, Object elem, YamlStyle style) {
  if (index == list.length) return addToFlowList(yaml, list, elem, style);
  if (index == 0) return prependToFlowList(yaml, list, elem, style);

  var valueString = ' ' + getFlowString(elem);
  if (list.nodes.isNotEmpty) valueString = '$valueString,';

  final currNode = list.nodes[index];
  final currNodeStartIdx = currNode.span.start.offset;
  final startOffset = yaml.lastIndexOf(RegExp(r',|\['), currNodeStartIdx) + 1;

  return SourceEdit(startOffset, 0, valueString);
}

/// Performs the string operation on [yaml] to achieve the effect of insertion
/// [elem] into [nodes] at [index], noting that this is a block list. [index] should
/// be non-negative and less than or equal to [length].
SourceEdit insertInBlockList(
    String yaml, YamlList list, int index, Object elem, YamlStyle style) {
  if (index == list.length) {
    return addToBlockList(yaml, list, elem, style);
  }
  if (index == 0) return prependToBlockList(yaml, list, elem, style);

  final finalIndentation =
      getListIndentation(yaml, list) + style.indentationStep;
  final valueString = getBlockString(elem, finalIndentation);
  var formattedValue = ' ' * getListIndentation(yaml, list) + '- ';

  if (isCollection(elem)) {
    formattedValue += '\n$valueString\n';
  } else {
    formattedValue += valueString + '\n';
  }

  final currNode = list.nodes[index];
  final currNodeStartIdx = currNode.span.start.offset;
  final startOffset = yaml.lastIndexOf('\n', currNodeStartIdx) + 1;

  return SourceEdit(startOffset, 0, formattedValue);
}

/// Performs the string operation on [yaml] to achieve the effect of addition
/// [elem] into [nodes], noting that this is a flow list.
SourceEdit addToFlowList(
    String yaml, YamlList list, Object elem, YamlStyle style) {
  var valueString = getFlowString(elem);
  if (list.nodes.isNotEmpty) valueString = ', ' + valueString;

  return SourceEdit(list.span.end.offset - 1, 0, valueString);
}

/// Performs the string operation on [yaml] to achieve the effect of addition
/// [elem] into [nodes], noting that this is a
/// block list.
SourceEdit addToBlockList(
    String yaml, YamlList list, Object elem, YamlStyle style) {
  final valueString = getBlockString(
      elem, getListIndentation(yaml, list) + style.indentationStep);
  var formattedValue = ''.padLeft(getListIndentation(yaml, list)) + '- ';

  if (isCollection(elem)) {
    formattedValue += valueString
            .substring(getListIndentation(yaml, list) + style.indentationStep) +
        '\n';
  } else {
    formattedValue += valueString + '\n';
  }

  // Adjusts offset to after the trailing newline of the last entry, if it exists
  if (list.nodes.isNotEmpty) {
    final lastValueSpanEnd = list.nodes.last.span.end.offset;
    final nextNewLineIndex = yaml.indexOf('\n', lastValueSpanEnd);
    if (nextNewLineIndex == -1) {
      formattedValue = '\n' + formattedValue;
    }
  }

  return SourceEdit(list.span.end.offset, 0, formattedValue);
}
