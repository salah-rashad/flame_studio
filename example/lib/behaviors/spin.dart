import 'dart:math' as math;

import 'package:pyro_runtime/pyro_runtime.dart';

/// Turns its entity continuously, so any change to its fields shows in the
/// running game within a frame (spec 005, contracts/example-game.md).
@PyroBehavior()
class Spin extends Behavior<PyroEntity> {
  /// Full turns per second.
  @Editable(min: 0, max: 4)
  double turnsPerSecond = 0.25;

  /// Whether it turns clockwise (Flame's positive angle) or the other way.
  @Editable()
  bool clockwise = true;

  @override
  void update(double dt) {
    final step = turnsPerSecond * 2 * math.pi * dt;
    parent.angle += clockwise ? step : -step;
  }
}
