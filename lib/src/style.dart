/// Style configuration settings for [YamlEditor] when modifying the YAML string.
class YamlStyle {
  /// The number of additional spaces from the starting column between block YAML elements
  /// of adjacent levels.
  final int indentationStep;

  /// Enforce flow structures when adding or modifying values. If this value is false,
  /// we try to make collections in block style where possible.
  final bool enforceFlow;

  const YamlStyle({this.indentationStep = 2, this.enforceFlow = false});

  /// Creates a new [YamlStyle] with the same configuration options as before, except for
  /// the properties specified in arguments.
  YamlStyle withOpts({int indentStep, bool useFlow}) {
    indentStep ??= indentationStep;
    useFlow ??= enforceFlow;

    return YamlStyle(indentationStep: indentStep, enforceFlow: useFlow);
  }
}
