import '../scene/errors.dart';
import '../scene/json/strict_reader.dart';
import '../scene/values.dart';
import 'animation_file.dart';

/// Reads animation files (`*.anim.json`) with the rules of
/// contracts/anim-file-v1.md.
abstract final class AnimationCodec {
  /// Reads the animation file at [path] from [text].
  ///
  /// Throws a [SceneFormatException]: [MalformedJson] or [DuplicateKey] from
  /// the JSON reader, or [InvalidAnimationFile] for a broken rule. Keys this
  /// version doesn't know are ignored.
  static AnimationFile decode(String text, {required String path}) =>
      _Reader(path).read(readStrictJson(text));
}

final class _Reader {
  _Reader(this.path);

  final String path;

  Never _fail(String reason) => throw InvalidAnimationFile(path, reason);

  AnimationFile read(Object? json) {
    if (json is! Map<String, Object?>) _fail('must hold a JSON object');
    // The version gate runs first: a newer file may hold data this reader
    // would misread.
    final version = json['schemaVersion'];
    if (version == null) _fail('has no schemaVersion');
    if (version is! int || version < 1) {
      _fail('schemaVersion must be a positive whole number, found $version');
    }
    if (version > AnimationFile.currentSchemaVersion) {
      _fail(
        'it has schemaVersion $version, but this version of pyro_runtime '
        'reads up to schemaVersion ${AnimationFile.currentSchemaVersion}. '
        'Update Pyro and pyro_runtime to use it.',
      );
    }
    final image = json['image'];
    if (image is! String || image.isEmpty) {
      _fail('image is missing or not a non-empty string');
    }
    final grid = _object(json['grid'], 'grid');
    final cellSize = _vector(grid['cellSize'], 'grid.cellSize');
    if (cellSize == null) _fail('grid.cellSize is missing');
    if (cellSize.x <= 0 || cellSize.y <= 0) {
      _fail('grid.cellSize must be greater than 0 in both directions');
    }
    final offset = _vector(grid['offset'], 'grid.offset') ?? Vec2.zero;
    final spacing = _vector(grid['spacing'], 'grid.spacing') ?? Vec2.zero;
    for (final (name, value) in [
      ('grid.offset', offset),
      ('grid.spacing', spacing),
    ]) {
      if (value.x < 0 || value.y < 0) _fail('$name must not be negative');
    }
    final animations = _object(json['animations'], 'animations');
    if (animations.isEmpty) _fail('animations holds no animation');
    return AnimationFile(
      path: AssetPath(path),
      image: AssetPath(image),
      grid: AnimationGrid(cellSize: cellSize, offset: offset, spacing: spacing),
      animations: {
        for (final MapEntry(:key, :value) in animations.entries)
          key: _clip(key, value),
      },
    );
  }

  AnimationClip _clip(String name, Object? json) {
    if (name.isEmpty) _fail('an animation has an empty name');
    final where = 'animations.$name';
    final clip = _object(json, where);
    final frames = clip['frames'];
    if (frames is! List<Object?> || frames.isEmpty) {
      _fail('$where.frames must be a non-empty array of cell indexes');
    }
    for (final frame in frames) {
      if (frame is! int || frame < 0) {
        _fail('$where.frames must hold whole numbers ≥ 0, found $frame');
      }
    }
    final stepTime = clip['stepTime'];
    final stepTimes = clip['stepTimes'];
    if ((stepTime == null) == (stepTimes == null)) {
      _fail('$where needs exactly one of stepTime and stepTimes');
    }
    double? fixed;
    List<double>? variable;
    if (stepTime != null) {
      fixed = _stepTime(stepTime, '$where.stepTime');
    } else {
      if (stepTimes is! List<Object?> || stepTimes.length != frames.length) {
        _fail(
          '$where.stepTimes must be an array with one time per frame '
          '(${frames.length})',
        );
      }
      variable = [
        for (final (i, time) in stepTimes.indexed)
          _stepTime(time, '$where.stepTimes[$i]'),
      ];
    }
    final loop = clip['loop'] ?? true;
    if (loop is! bool) _fail('$where.loop must be true or false');
    return AnimationClip(
      frames: frames.cast<int>(),
      stepTime: fixed,
      stepTimes: variable,
      loop: loop,
    );
  }

  double _stepTime(Object? value, String where) {
    if (value is! num || !value.isFinite || value <= 0) {
      _fail('$where must be a number of seconds greater than 0');
    }
    return value.toDouble();
  }

  Map<String, Object?> _object(Object? value, String where) {
    if (value is! Map<String, Object?>) {
      _fail('$where is missing or not a JSON object');
    }
    return value;
  }

  Vec2? _vector(Object? value, String where) {
    if (value == null) return null;
    if (value case [final num x, final num y] when x.isFinite && y.isFinite) {
      return Vec2(x.toDouble(), y.toDouble());
    }
    _fail('$where must be [x, y]');
  }
}
