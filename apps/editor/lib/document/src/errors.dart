import 'package:pyro_runtime/pyro_runtime.dart';

/// Why an edit to a `SceneDocument` was refused (spec 002, FR-007, FR-008).
///
/// Every case names the Node involved and, when known, its Node name.
sealed class DocumentEditError implements Exception {
  const DocumentEditError(this.id, {this.nodeName});

  /// The Node the edit was about.
  final NodeId id;

  /// The Node's name, when it has one.
  final String? nodeName;

  /// What went wrong, without the Node.
  String get problem;

  @override
  String toString() {
    final name = nodeName == null ? '' : ' ($nodeName)';
    return 'Node "$id"$name: $problem';
  }
}

/// A Node with this ID is already in the Scene.
final class DuplicateNodeId extends DocumentEditError {
  const DuplicateNodeId(super.id, {super.nodeName});

  @override
  String get problem => 'a Node with this ID already exists';
}

/// No Node has this ID.
final class NodeNotFound extends DocumentEditError {
  const NodeNotFound(super.id);

  @override
  String get problem => 'no such Node in the Scene';
}

/// The edit would add, remove, move or turn something into the root.
final class RootNotAllowed extends DocumentEditError {
  const RootNotAllowed(super.id, this.operation, {super.nodeName});

  /// The edit that was refused, such as `remove`.
  final String operation;

  @override
  String get problem => 'the root can\'t be used in $operation';
}

/// An added Node already lists children; add them one at a time.
final class NodeHasChildren extends DocumentEditError {
  const NodeHasChildren(super.id, {super.nodeName});

  @override
  String get problem => 'a Node is added without children';
}

/// The position among the parent's children is outside the list.
final class IndexOutOfRange extends DocumentEditError {
  const IndexOutOfRange(
    super.id, {
    required this.parentId,
    required this.index,
    required this.length,
    super.nodeName,
  });

  /// The parent the Node was to go under.
  final NodeId parentId;

  /// The requested position.
  final int index;

  /// How many children the parent has (valid positions are 0 to [length]).
  final int length;

  @override
  String get problem =>
      'position $index is outside 0..$length among the children of "$parentId"';
}

/// The Node would move under itself or one of its descendants.
final class MoveIntoOwnSubtree extends DocumentEditError {
  const MoveIntoOwnSubtree(
    super.id, {
    required this.targetParentId,
    super.nodeName,
  });

  /// The parent it was to move under.
  final NodeId targetParentId;

  @override
  String get problem =>
      'can\'t move under "$targetParentId", which is inside its own subtree';
}

/// A replacement Node changes the children; use add, remove or move.
final class ChildrenChanged extends DocumentEditError {
  const ChildrenChanged(super.id, {super.nodeName});

  @override
  String get problem =>
      'a replacement must keep the same children; add, remove or move them '
      'instead';
}

/// A transaction failed; the document is unchanged (FR-008).
final class TransactionFailed implements Exception {
  const TransactionFailed(this.label, this.cause);

  /// The transaction's name, such as `Move 3 Nodes`.
  final String label;

  /// Why it failed.
  final DocumentEditError cause;

  @override
  String toString() => 'Transaction "$label" failed: $cause';
}

/// A Scene file couldn't be opened (FR-017).
final class SceneOpenFailed implements Exception {
  const SceneOpenFailed(this.path, this.cause);

  /// The file's path.
  final String path;

  /// The underlying error: a file-system error, a `FormatException` for bytes
  /// that aren't UTF-8, or a `SceneFormatException`.
  final Object cause;

  @override
  String toString() => 'Can\'t open Scene "$path": $cause';
}

/// A save was refused before anything was read or written.
sealed class SaveRefused implements Exception {
  const SaveRefused();
}

/// The newest `schemaVersion` the project's Runtime reads isn't known yet
/// (FR-022).
final class RuntimeVersionUnknown extends SaveRefused {
  const RuntimeVersionUnknown(this.path);

  /// The Scene that wasn't saved, or null for a new Scene.
  final String? path;

  @override
  String toString() =>
      'Not saving Scene "${path ?? 'untitled'}": the Scene version the '
      'project\'s pyro_runtime reads isn\'t known yet';
}

/// The project's Runtime can't read the version Pyro writes (FR-022, *Q49*).
final class RuntimeTooOld extends SaveRefused {
  const RuntimeTooOld(this.path, {required this.reads, required this.writes});

  /// The Scene that wasn't saved, or null for a new Scene.
  final String? path;

  /// The newest `schemaVersion` the project's Runtime reads.
  final int reads;

  /// The `schemaVersion` Pyro writes.
  final int writes;

  @override
  String toString() =>
      'Not saving Scene "${path ?? 'untitled'}": the project\'s pyro_runtime '
      'reads Scene version $reads at most, and Pyro writes version $writes. '
      'Upgrade pyro_runtime in the project to save.';
}

/// The Scene file changed on disk since it was opened or last saved
/// (FR-019a).
final class SceneChangedOnDisk extends SaveRefused {
  const SceneChangedOnDisk(this.path);

  /// The Scene file.
  final String path;

  @override
  String toString() =>
      'Not saving Scene "$path": the file changed on disk since it was opened '
      'or last saved';
}

/// "Save as", or a first save, onto a file that already exists (FR-019a).
final class SaveTargetExists extends SaveRefused {
  const SaveTargetExists(this.path);

  /// The existing file.
  final String path;

  @override
  String toString() => 'Not saving: "$path" already exists';
}

/// A new Scene was saved without a path (FR-021).
final class SavePathRequired extends SaveRefused {
  const SavePathRequired();

  @override
  String toString() => 'Not saving: a new Scene needs a file path';
}

/// Writing a Scene file failed; the file is as it was (FR-019).
final class SaveFailed implements Exception {
  const SaveFailed(this.path, this.cause);

  /// The Scene file.
  final String path;

  /// The underlying error.
  final Object cause;

  @override
  String toString() => 'Saving Scene "$path" failed: $cause';
}

/// Writing a recovery copy failed; editing goes on (FR-024).
final class RecoveryWriteFailed implements Exception {
  const RecoveryWriteFailed(this.location, this.cause);

  /// The recovery folder or file.
  final String location;

  /// The underlying error.
  final Object cause;

  @override
  String toString() =>
      'Writing the recovery copy in "$location" failed: $cause';
}
