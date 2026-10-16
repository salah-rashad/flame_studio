import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import 'dart_marker.dart';
import 'studio_scene.dart';

class SpikeGame extends FlameGame {
  late StudioScene scene;
  late final TextComponent hud;

  @override
  Future<void> onLoad() async {
    scene = await StudioScene.load(
      'assets/scenes/level1.scene.json',
      onReloaded: (s) => scene = s,
    );
    world.add(scene);

    hud = TextComponent(
      position: Vector2.all(12),
      textRenderer: TextPaint(
        style: const TextStyle(fontSize: 14, color: Color(0xFFFFFFFF)),
      ),
    );
    camera.viewport.add(hud);
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Read every frame so a Dart-only hot reload shows up immediately.
    hud.text = 'rebuilds: ${scene.rebuildCount}   '
        'hash: ${scene.hash.substring(0, 8)}   '
        'code: $dartMarker';
  }
}
