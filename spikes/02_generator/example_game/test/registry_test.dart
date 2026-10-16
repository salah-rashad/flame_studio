import 'dart:convert';
import 'dart:io';

import 'package:example_game/behaviors/patrol.dart';
import 'package:example_game/components/player.dart';
import 'package:example_game/flame_studio.g.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Registry creates types and sets fields from scene-style values', () {
    final patrol = studioRegistry['Patrol']!.create() as Patrol;
    final s = studioRegistry['Patrol']!.setters;
    s['speed']!(patrol, 120); // JSON ints arrive as int
    s['mode']!(patrol, 'loop');
    s['direction']!(patrol, Vector2(0, 1));
    final player = studioRegistry['Player']!.create() as Player;
    s['target']!(patrol, player);
    expect(patrol.speed, 120.0);
    expect(patrol.mode, PatrolMode.loop);
    expect(patrol.direction, Vector2(0, 1));
    expect(patrol.target, same(player));
  });

  test('Registry and Manifest list the same Type IDs', () {
    final manifest = jsonDecode(
      File('lib/flame_studio.manifest.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final ids = [for (final t in manifest['types'] as List) t['id']];
    expect(ids, studioRegistry.keys.toList());
  });
}
