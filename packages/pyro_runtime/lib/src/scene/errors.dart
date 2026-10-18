import 'values.dart';

/// A Scene file that can't be read, or a Scene that can't be written.
///
/// Every subtype names what failed and where (FR-026), so the message can be
/// shown to the developer as it is.
sealed class SceneFormatException implements Exception {
  const SceneFormatException();

  /// What went wrong, naming the Node, key or position involved.
  String get message;

  @override
  String toString() => 'SceneFormatException: $message';
}

/// The file isn't valid JSON.
final class MalformedJson extends SceneFormatException {
  /// Creates the error for [reason] at [offset] (a code-unit index into the
  /// text), which is [line] and [column] (both 1-based).
  const MalformedJson(
    this.reason, {
    required this.offset,
    required this.line,
    required this.column,
  });

  /// What the reader expected or found.
  final String reason;

  /// Code-unit index of the problem in the text.
  final int offset;

  /// 1-based line of the problem.
  final int line;

  /// 1-based column of the problem, in code units.
  final int column;

  @override
  String get message => 'Malformed JSON at line $line, column $column: $reason';
}

/// An object in the file holds the same key twice, for example after a bad
/// merge. Pyro refuses the file rather than silently keep one of the values.
final class DuplicateKey extends SceneFormatException {
  /// Creates the error for [key], found again in the object at [path].
  const DuplicateKey(
    this.key, {
    required this.path,
    required this.line,
    required this.column,
  });

  /// The repeated key.
  final String key;

  /// Where the object is, such as `nodes.3f1c.transform` or `b[0]`; empty
  /// for the top level.
  final String path;

  /// 1-based line of the second occurrence.
  final int line;

  /// 1-based column of the second occurrence.
  final int column;

  @override
  String get message {
    final where = path.isEmpty ? 'the top level' : '"$path"';
    return 'Duplicate key "$key" in $where at line $line, column $column';
  }
}

/// The file was saved by a newer Pyro, with a `schemaVersion` this reader
/// doesn't support (FR-019).
final class UnsupportedSchemaVersion extends SceneFormatException {
  /// Creates the error for a file at version [found] when this reader
  /// supports up to [supported].
  const UnsupportedSchemaVersion({
    required this.found,
    required this.supported,
  });

  /// The file's `schemaVersion`.
  final int found;

  /// The newest `schemaVersion` this reader supports.
  final int supported;

  @override
  String get message =>
      'This Scene has schemaVersion $found, but this version of Pyro reads '
      'up to schemaVersion $supported. Update Pyro (and pyro_runtime in the '
      'game) to open it.';
}

/// The file's `schemaVersion` is missing or isn't a positive whole number
/// (FR-020).
final class InvalidSchemaVersion extends SceneFormatException {
  /// Creates the error for a file without a `schemaVersion`.
  const InvalidSchemaVersion.missing() : found = null, isMissing = true;

  /// Creates the error for a `schemaVersion` of [found].
  const InvalidSchemaVersion(this.found) : isMissing = false;

  /// The value found, when there was one.
  final Object? found;

  /// Whether the key was absent.
  final bool isMissing;

  @override
  String get message => isMissing
      ? 'The Scene has no schemaVersion'
      : 'schemaVersion must be a positive whole number, found '
            '${found is String ? '"$found"' : found}';
}

/// The file's top level or root Node is invalid: `rootId` or `nodes` is
/// missing or of the wrong type, `rootId` names no Node or a Node that isn't
/// the root, or more than one Node has kind `root`.
final class InvalidRoot extends SceneFormatException {
  /// Creates the error described by [reason].
  const InvalidRoot(this.reason);

  /// What is wrong.
  final String reason;

  @override
  String get message => reason;
}

/// A Node in the file has a missing key, or a key of the wrong type.
final class InvalidNode extends SceneFormatException {
  /// Creates the error for Node [nodeId]; [key] is the offending key's path
  /// inside the Node, such as `transform.position` or `behaviors[1].type`.
  const InvalidNode(
    this.nodeId,
    this.reason, {
    this.nodeName,
    this.typeId,
    this.key,
  });

  /// The Node's ID.
  final NodeId nodeId;

  /// The Node's name, when it was read before the error.
  final String? nodeName;

  /// The Node's Type ID, for Custom components.
  final TypeId? typeId;

  /// The key involved, when there is one.
  final String? key;

  /// What is wrong.
  final String reason;

  @override
  String get message {
    final node = StringBuffer('Node "$nodeId"');
    if (nodeName != null) node.write(' ("$nodeName")');
    if (typeId != null) node.write(' of type $typeId');
    final at = key == null ? '' : ', key "$key"';
    return '$node$at: $reason';
  }
}

/// A value in the Scene can't be written to JSON: a NaN or infinite number,
/// or something that isn't a JSON value.
final class UnwritableValue extends SceneFormatException {
  /// Creates the error for [value] at [key] of Node [nodeId]; [nodeId] is
  /// null for a top-level key.
  const UnwritableValue(this.value, {required this.key, this.nodeId});

  /// The Node holding the value, or null at the top level.
  final NodeId? nodeId;

  /// The key path of the value inside the Node, or the top-level key.
  final String key;

  /// The value that can't be written.
  final Object? value;

  @override
  String get message {
    final where = nodeId == null
        ? 'top-level key "$key"'
        : 'Node "$nodeId", key "$key"';
    return "Can't write $value at $where: only finite numbers and JSON values "
        'can be saved in a Scene';
  }
}
