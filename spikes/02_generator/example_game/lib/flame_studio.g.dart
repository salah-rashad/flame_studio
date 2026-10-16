// GENERATED CODE - DO NOT MODIFY BY HAND.
// Flame Studio Registry (spike #2).
// ignore_for_file: type=lint, implementation_imports

import 'dart:ui' as i0;
import 'package:example_game/behaviors/patrol.dart' as i1;
import 'package:example_game/components/coin.dart' as i2;
import 'package:example_game/components/player.dart' as i3;
import 'package:flame/src/sprite_animation.dart' as i4;
import 'package:vector_math/vector_math.dart' as i5;

typedef StudioSetter = void Function(Object target, Object? value);

class StudioType {
  const StudioType(this.id, this.create, this.setters);
  final String id;
  final Object Function() create;
  final Map<String, StudioSetter> setters;
}

final studioRegistry = <String, StudioType>{
  'Patrol': StudioType('Patrol', i1.Patrol.new, {
    'speed': (t, v) => (t as i1.Patrol).speed = (v as num).toDouble(),
    'direction': (t, v) => (t as i1.Patrol).direction = v as i5.Vector2,
    'mode': (t, v) =>
        (t as i1.Patrol).mode = i1.PatrolMode.values.byName(v as String),
    'target': (t, v) => (t as i1.Patrol).target = v as i3.Player?,
    'hitEffect': (t, v) =>
        (t as i1.Patrol).hitEffect = v as i4.SpriteAnimation?,
  }),
  'Player': StudioType('Player', i3.Player.new, {
    'lives': (t, v) => (t as i3.Player).lives = (v as num).toInt(),
    'invincible': (t, v) => (t as i3.Player).invincible = v as bool,
    'nickname': (t, v) => (t as i3.Player).nickname = v as String,
    'tint': (t, v) => (t as i3.Player).tint = v as i0.Color,
  }),
  'pickup.coin': StudioType('pickup.coin', i2.Coin.new, {
    'value': (t, v) => (t as i2.Coin).value = (v as num).toInt(),
  }),
};
