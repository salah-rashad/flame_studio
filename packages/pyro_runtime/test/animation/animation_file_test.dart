import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_runtime/pyro_runtime.dart';
import 'package:pyro_runtime/src/animation/animation_codec.dart';
import 'package:pyro_runtime/src/animation/animation_file.dart';
import 'package:pyro_runtime/src/animation/sprite_sheet.dart';

import '../support/images.dart';

const _path = 'assets/anims/goblin.anim.json';

AnimationFile _decode(String text) => AnimationCodec.decode(text, path: _path);

/// A file with [animation] as its only animation, and [grid] as its grid.
String _file({
  String animation = '{"frames": [0], "stepTime": 0.1}',
  String grid = '{"cellSize": [32, 32]}',
  String extra = '',
}) =>
    '{"schemaVersion": 1, "image": "assets/images/sheet.png", '
    '"grid": $grid, "animations": {"walk": $animation}$extra}';

Matcher _refused(String reason) => throwsA(
  isA<InvalidAnimationFile>().having(
    (e) => e.message,
    'message',
    allOf(contains(_path), contains(reason)),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("reads project plan §7.2's example", () {
    final file = _decode('''
{
  "schemaVersion": 1,
  "image": "assets/images/goblin_sheet.png",
  "grid": { "cellSize": [32, 32], "offset": [0, 0], "spacing": [0, 0] },
  "animations": {
    "walk": { "frames": [4, 5, 6, 7], "stepTime": 0.1, "loop": true },
    "idle": { "frames": [0, 1], "stepTimes": [0.4, 0.2], "loop": true }
  }
}''');
    expect(file.image, 'assets/images/goblin_sheet.png');
    expect(file.grid.cellSize, const Vec2(32, 32));
    expect(file.animations.keys, ['walk', 'idle']);
    expect(file.animations['walk']!.frames, [4, 5, 6, 7]);
    expect(file.animations['walk']!.stepTime, 0.1);
    expect(file.animations['idle']!.stepTimes, [0.4, 0.2]);
  });

  test('offset and spacing default to [0, 0], loop to true', () {
    final file = _decode(_file());
    expect(file.grid.offset, Vec2.zero);
    expect(file.grid.spacing, Vec2.zero);
    expect(file.animations['walk']!.loop, isTrue);
  });

  test('unknown keys are ignored', () {
    final file = _decode(_file(extra: ', "slices": {"x": 1}'));
    expect(file.animations, hasLength(1));
  });

  test('a newer schemaVersion is refused, naming the supported one', () {
    expect(
      () => _decode(
        _file().replaceFirst('"schemaVersion": 1', '"schemaVersion": 2'),
      ),
      _refused('reads up to schemaVersion 1'),
    );
  });

  test('duplicate keys are refused with a line and column', () {
    expect(
      () => _decode('{"schemaVersion": 1,\n"schemaVersion": 1}'),
      throwsA(isA<DuplicateKey>().having((e) => e.line, 'line', 2)),
    );
  });

  group('broken rules are refused', () {
    final cases = <String, (String, String)>{
      'missing schemaVersion': (
        '{"image": "a.png", "grid": {"cellSize": [1, 1]}, "animations": {}}',
        'no schemaVersion',
      ),
      'missing image': (
        _file().replaceFirst('"image": "assets/images/sheet.png", ', ''),
        'image',
      ),
      'missing cellSize': (_file(grid: '{}'), 'grid.cellSize'),
      'cellSize of 0': (_file(grid: '{"cellSize": [0, 32]}'), 'grid.cellSize'),
      'negative offset': (
        _file(grid: '{"cellSize": [32, 32], "offset": [-1, 0]}'),
        'grid.offset',
      ),
      'missing animations': (
        '{"schemaVersion": 1, "image": "a.png", "grid": {"cellSize": [1, 1]}}',
        'animations',
      ),
      'no animation': (
        '{"schemaVersion": 1, "image": "a.png", "grid": {"cellSize": [1, 1]}, '
            '"animations": {}}',
        'holds no animation',
      ),
      'empty frames': (
        _file(animation: '{"frames": [], "stepTime": 1}'),
        'frames',
      ),
      'negative frame': (
        _file(animation: '{"frames": [-1], "stepTime": 1}'),
        'frames',
      ),
      'both step forms': (
        _file(animation: '{"frames": [0], "stepTime": 1, "stepTimes": [1]}'),
        'exactly one of stepTime and stepTimes',
      ),
      'no step form': (
        _file(animation: '{"frames": [0]}'),
        'exactly one of stepTime and stepTimes',
      ),
      'stepTimes of the wrong length': (
        _file(animation: '{"frames": [0, 1], "stepTimes": [1]}'),
        'one time per frame',
      ),
      'a step time of 0': (
        _file(animation: '{"frames": [0], "stepTime": 0}'),
        'greater than 0',
      ),
      'loop not a boolean': (
        _file(animation: '{"frames": [0], "stepTime": 1, "loop": 1}'),
        'loop',
      ),
    };
    for (final MapEntry(key: name, value: (text, reason)) in cases.entries) {
      test(name, () => expect(() => _decode(text), _refused(reason)));
    }
  });

  group('frames → cells', () {
    test('columns, offset and spacing place each frame', () async {
      final file = _decode(
        _file(
          grid: '{"cellSize": [32, 32], "offset": [2, 0], "spacing": [1, 0]}',
          animation: '{"frames": [0, 4], "stepTimes": [0.4, 0.2]}',
        ),
      );
      // (100 - 2 + 1) / 33 = 3 columns; 64 / 32 = 2 rows.
      final animation = toSpriteAnimation(
        file,
        'walk',
        await makeImage(100, 64),
      );
      expect(animation.frames[0].sprite.srcPosition, Vector2(2, 0));
      expect(animation.frames[1].sprite.srcPosition, Vector2(35, 32));
      expect(animation.frames[1].sprite.srcSize, Vector2(32, 32));
      expect([for (final f in animation.frames) f.stepTime], [0.4, 0.2]);
    });

    test(
      'a frame outside the image names the file, animation and frame',
      () async {
        final file = _decode(
          _file(animation: '{"frames": [6], "stepTime": 1}'),
        );
        expect(
          () async => toSpriteAnimation(file, 'walk', await makeImage(100, 64)),
          throwsA(
            isA<RangeError>().having(
              (e) => e.message,
              'message',
              allOf(contains(_path), contains('"walk"'), contains('frame 6')),
            ),
          ),
        );
      },
    );
  });
}
