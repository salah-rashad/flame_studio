import '../scene/values.dart';

/// A Scene that couldn't be loaded, with everything that names the cause:
/// the Scene, and where they apply the Node, Type ID, field and asset
/// (constitution I).
final class SceneLoadException implements Exception {
  /// Creates the error for the Scene at [scene], described by [message].
  const SceneLoadException(
    this.scene,
    this.message, {
    this.nodeId,
    this.nodeName,
    this.typeId,
    this.field,
    this.asset,
    this.cause,
    this.causeStackTrace,
  });

  /// The Scene's asset path.
  final AssetPath scene;

  /// The ID of the Node involved, if any.
  final NodeId? nodeId;

  /// The name of the Node involved, if it has one.
  final String? nodeName;

  /// The Type ID involved, if any.
  final TypeId? typeId;

  /// The Editable field involved, if any.
  final String? field;

  /// The asset involved, if any.
  final AssetPath? asset;

  /// What went wrong and how to fix it.
  final String message;

  /// The underlying error: a `SceneFormatException`, an error thrown by
  /// user code, or the asset bundle's error.
  final Object? cause;

  /// Where [cause] was thrown.
  final StackTrace? causeStackTrace;

  /// The Node as messages name it: `Node "goblin_1" (3f1c)`, or
  /// `Node (3f1c)` when it has no name.
  String? get _node => switch ((nodeId, nodeName)) {
    (null, _) => null,
    (final id, null) => 'Node ($id)',
    (final id, final name) => 'Node "$name" ($id)',
  };

  @override
  String toString() {
    final where = [
      ?_node,
      if (field != null) typeId == null ? field! : '$typeId.$field',
      if (field == null && typeId != null) typeId!,
      if (asset != null) 'asset $asset',
    ];
    final text = StringBuffer('$scene: ');
    if (where.isNotEmpty) text.write('${where.join(', ')}: ');
    text.write(message);
    if (cause != null) text.write('\nCaused by: $cause');
    return text.toString();
  }
}
