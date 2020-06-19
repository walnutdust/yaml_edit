/// Error thrown when a function is passed an invalid path.
class PathError extends ArgumentError {
  /// The path that caused the error
  final Iterable<Object> path;

  /// The last element of [path] that could be traversed.
  Object parentNode;

  PathError(this.path, Object invalidKeyOrIndex, this.parentNode,
      [String message])
      : super.value(invalidKeyOrIndex, 'path', message);

  PathError.unexpected(this.path, String message) : super(message);

  @override
  String toString() {
    if (message == null) {
      return 'Invalid path: $path. Missing key or index $invalidValue in parent $parentNode.';
    }

    return 'Invalid path: $path. $message';
  }
}
