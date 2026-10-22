import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import 'code_marker.dart';
import 'pyro.g.dart';

/// The Scene the game shows.
const scenePath = 'assets/scenes/level1.scene.json';

/// Loads [scenePath] through the generated Registry and shows a HUD that
/// lives outside the Scene, so a Hot-swap can be seen to keep the game's
/// own state (spec 005, contracts/example-game.md).
class ExampleGame extends FlameGame {
  /// Creates the game with an 800×600 world.
  ExampleGame()
    : super(
        camera: CameraComponent.withFixedResolution(width: 800, height: 600),
      );

  /// The loaded Scene.
  late final PyroScene scene;

  /// How many times the Scene was Hot-swapped.
  int swaps = 0;

  double _seconds = 0;
  late final TextComponent _hud;

  @override
  Future<void> onLoad() async {
    camera.viewfinder
      ..anchor = Anchor.topLeft
      ..position = Vector2.zero();
    scene = await PyroScene.load(
      scenePath,
      registry: pyroRegistry,
      onReloaded: _onReloaded,
    );
    await world.add(scene);
    _hud = TextComponent(text: _hudText, position: Vector2(12, 560));
    await camera.viewport.add(_hud);
    // The latency benchmark and the manual check wait for these lines
    // (spec 005, research R14); keep them exactly as they are.
    debugPrint('[pyro_example] Scene loaded: $scenePath');
  }

  void _onReloaded(PyroScene scene) {
    swaps++;
    debugPrint('[pyro_example] Scene reloaded: $scenePath');
  }

  /// The HUD's text: time, Hot-swaps and the code marker.
  String get hudText => _hudText;

  String get _hudText =>
      'time: ${_seconds.floor()}s  swaps: $swaps  code: $codeMarker';

  @override
  void update(double dt) {
    super.update(dt);
    _seconds += dt;
    if (isLoaded) _hud.text = _hudText;
  }
}
