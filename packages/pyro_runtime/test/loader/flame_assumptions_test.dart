// Pins the Flame and flame_behaviors behavior the loader is built on
// (spec 004 research, facts marked *read*). If a Flame upgrade breaks one of
// these, the loader's design needs another look before its own tests fail.
import 'package:flame/cache.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/images.dart';

class _Entity extends PositionedEntity {}

class _Behavior extends Behavior<PositionedEntity> {}

class _Probe extends PositionComponent {
  _Probe(this.log, this.name);

  final List<String> log;
  final String name;
  int hotReloads = 0;

  @override
  Future<void> onLoad() async => log.add('load $name');

  @override
  void onHotReload() {
    hotReloads++;
    super.onHotReload();
  }
}

class _RecordingBundle extends CachingAssetBundle {
  _RecordingBundle(this.data);

  final ByteData data;
  final List<String> keys = [];

  @override
  Future<ByteData> load(String key) async {
    keys.add(key);
    return data;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWithFlameGame('R3: a concrete PositionedEntity holds a Behavior', (
    game,
  ) async {
    final entity = _Entity();
    final behavior = _Behavior();
    await entity.add(behavior);
    await game.ensureAdd(entity);
    expect(entity.findBehavior<_Behavior>(), same(behavior));
  });

  testWithFlameGame('R3: hitboxes with a position and size never fill their '
      'parent', (game) async {
    final parent = PositionComponent(size: Vector2.all(100));
    final rectangle = RectangleHitbox(
      position: Vector2(4, 2),
      size: Vector2(24, 30),
    );
    final circle = CircleHitbox(radius: 5, position: Vector2.zero());
    await parent.addAll([rectangle, circle]);
    await game.ensureAdd(parent);
    expect(rectangle.size, Vector2(24, 30));
    expect(rectangle.position, Vector2(4, 2));
    expect(circle.radius, 5);
  });

  testWithFlameGame('R11: game.onHotReload reaches mounted and loading '
      'children, not components never added', (game) async {
    final log = <String>[];
    final mounted = _Probe(log, 'mounted');
    await game.ensureAdd(mounted);
    final pending = _Probe(log, 'pending');
    await game.add(pending);
    final loose = _Probe(log, 'loose');

    game.onHotReload();

    expect(mounted.hotReloads, 1);
    expect(pending.hotReloads, 1);
    expect(loose.hotReloads, 0);
  });

  testWithFlameGame('R4: children added to an unmounted component load only '
      'once it is added, parents first', (game) async {
    final log = <String>[];
    final parent = _Probe(log, 'parent');
    final child = _Probe(log, 'child');
    final grandchild = _Probe(log, 'grandchild');
    await child.add(grandchild);
    await parent.add(child);
    await Future<void>.delayed(Duration.zero);
    expect(log, isEmpty);

    await game.ensureAdd(parent);
    await game.ready();
    expect(log, ['load parent', 'load child', 'load grandchild']);
  });

  testWithFlameGame('R12: a removed component\'s mounted future completes '
      'when it is added again', (game) async {
    final component = PositionComponent();
    await game.ensureAdd(component);
    component.removeFromParent();
    game.update(0);
    expect(component.isMounted, isFalse);

    var completed = false;
    component.mounted.then((_) => completed = true).ignore();
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);

    await game.ensureAdd(component);
    await Future<void>.delayed(Duration.zero);
    expect(completed, isTrue);
  });

  testWithFlameGame('R12: while removal is only queued, mounted is already '
      'complete', (game) async {
    final component = PositionComponent();
    await game.ensureAdd(component);
    component.removeFromParent();
    expect(component.isMounted, isTrue);

    var completed = false;
    component.mounted.then((_) => completed = true).ignore();
    await Future<void>.delayed(Duration.zero);
    expect(completed, isTrue);
  });

  testWithFlameGame('R12: a transform listener fires on a position change, '
      'not on removal', (game) async {
    final component = PositionComponent();
    await game.ensureAdd(component);
    var calls = 0;
    component.transform.addListener(() => calls++);

    component.removeFromParent();
    game.update(0);
    expect(calls, 0);

    component.position.x = 10;
    expect(calls, 1);
  });

  test(
    'R7: spriteList and variableSpriteList keep step times and loop',
    () async {
      final image = await makeImage(64, 32);
      final sprites = [
        Sprite(image, srcPosition: Vector2.zero(), srcSize: Vector2.all(32)),
        Sprite(image, srcPosition: Vector2(32, 0), srcSize: Vector2.all(32)),
      ];
      final fixed = SpriteAnimation.spriteList(
        sprites,
        stepTime: 0.1,
        loop: false,
      );
      expect([for (final f in fixed.frames) f.stepTime], [0.1, 0.1]);
      expect(fixed.loop, isFalse);

      final variable = SpriteAnimation.variableSpriteList(
        sprites,
        stepTimes: [0.4, 0.2],
      );
      expect([for (final f in variable.frames) f.stepTime], [0.4, 0.2]);
      expect(variable.loop, isTrue);
    },
  );

  test('R8: Images with an empty prefix asks the bundle for the key as '
      'given', () async {
    final png = await makePng(2, 2);
    final bundle = _RecordingBundle(ByteData.sublistView(png));
    final images = Images(prefix: '', bundle: bundle);
    await images.load('assets/images/a.png');
    expect(bundle.keys, ['assets/images/a.png']);
    // Flame's globals stay untouched.
    expect(Flame.images.containsKey('assets/images/a.png'), isFalse);
  });
}
