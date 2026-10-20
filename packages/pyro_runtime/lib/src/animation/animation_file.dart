import '../scene/values.dart';

/// One spritesheet's named animations, as read from an `.anim.json` file
/// (project plan §7.2, contracts/anim-file-v1.md).
final class AnimationFile {
  /// Creates the file's contents.
  AnimationFile({
    required this.path,
    required this.image,
    required this.grid,
    required Map<String, AnimationClip> animations,
  }) : animations = Map.unmodifiable(animations);

  /// The newest `schemaVersion` this version reads.
  static const int currentSchemaVersion = 1;

  /// The file's own asset path, for messages.
  final AssetPath path;

  /// The spritesheet's asset path.
  final AssetPath image;

  /// How the spritesheet is cut into cells.
  final AnimationGrid grid;

  /// The animations by name.
  final Map<String, AnimationClip> animations;
}

/// The cells of a spritesheet: [cellSize] each, the first at [offset], with
/// [spacing] between neighbours.
final class AnimationGrid {
  /// Creates the grid.
  const AnimationGrid({
    required this.cellSize,
    this.offset = Vec2.zero,
    this.spacing = Vec2.zero,
  });

  /// The width and height of one cell.
  final Vec2 cellSize;

  /// The top-left corner of cell 0.
  final Vec2 offset;

  /// The gap between neighbouring cells.
  final Vec2 spacing;
}

/// One named animation: its cell indexes and timing.
final class AnimationClip {
  /// Creates the animation; exactly one of [stepTime] and [stepTimes] is
  /// set (the reader checks it).
  AnimationClip({
    required List<int> frames,
    this.stepTime,
    List<double>? stepTimes,
    this.loop = true,
  }) : frames = List.unmodifiable(frames),
       stepTimes = stepTimes == null ? null : List.unmodifiable(stepTimes);

  /// The cell index of each frame, row by row.
  final List<int> frames;

  /// The time every frame shows, in seconds, or null if [stepTimes] is set.
  final double? stepTime;

  /// Each frame's time in seconds, or null if [stepTime] is set.
  final List<double>? stepTimes;

  /// Whether the animation starts again after its last frame.
  final bool loop;
}
