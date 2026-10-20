import 'dart:ui';

import 'package:pyro_runtime/pyro_runtime.dart';

import 'images.dart';
import 'memory_asset_source.dart';
import 'scene_text.dart';

// Fixture Scenes for the loader tests (spec 004), built in code and written
// by SceneCodec.encode, so they are canonical by construction.

/// The path every fixture Scene is served at.
const String scenePath = 'assets/scenes/test.scene.json';

/// The spritesheet sprites and animations use: 64×32, two 32×32 cells.
const String sheet = 'assets/images/sheet.png';

/// An animation file over [sheet] with `walk` (both cells, 0.1 s each) and
/// `idle` (cell 0, then cell 1, 0.4 s and 0.2 s, not looping).
const String fxAnim = 'assets/anims/fx.anim.json';

/// The text of [fxAnim].
const String fxAnimText =
    '''
{
  "schemaVersion": 1,
  "animations": {
    "idle": {"frames": [0, 1], "loop": false, "stepTimes": [0.4, 0.2]},
    "walk": {"frames": [0, 1], "stepTime": 0.1}
  },
  "grid": {"cellSize": [32, 32]},
  "image": "$sheet"
}
''';

/// A memory source serving [scene] at [scenePath], [fxAnim] and [sheet],
/// plus [texts].
Future<MemoryAssetSource> sourceFor(
  String scene, {
  Map<String, String> texts = const {},
}) async => MemoryAssetSource(
  texts: {scenePath: scene, fxAnim: fxAnimText, ...texts},
  images: <String, Image>{sheet: await makeImage(64, 32)},
);

/// Root → `goblin_1` (entity, tag `enemy`, `AllFields` twice) → a sprite
/// with a region and a rectangle hitbox; `player` (a Custom `Player` with
/// two Overrides) → a circle hitbox with a custom anchor.
String allKindsScene() => sceneJson([
  RootNode(
    id: const NodeId('root'),
    childIds: const [NodeId('goblin'), NodeId('player')],
  ),
  EntityNode(
    id: const NodeId('goblin'),
    name: 'goblin_1',
    tags: const ['enemy'],
    childIds: const [NodeId('sprite'), NodeId('rect')],
    transform: NodeTransform(
      position: const Vec2(320, 128),
      size: const Vec2(32, 32),
      scale: const Vec2(2, 1),
      angle: 0.5,
      anchor: NodeAnchor.center,
    ),
    behaviors: [
      BehaviorAttachment(type: const TypeId('AllFields')),
      BehaviorAttachment(
        type: const TypeId('AllFields'),
        fields: Overrides(const {'count': 2}),
      ),
    ],
  ),
  SpriteNode(
    id: const NodeId('sprite'),
    name: 'sprite',
    transform: at(0, 0, w: 32, h: 32),
    image: const AssetPath(sheet),
    region: const SpriteRegion(position: Vec2(32, 0), size: Vec2(32, 32)),
  ),
  RectangleHitboxNode(
    id: const NodeId('rect'),
    name: 'body',
    position: const Vec2(4, 2),
    size: const Vec2(24, 30),
    angle: 0.25,
    anchor: NodeAnchor.bottomCenter,
    collisionType: NodeCollisionType.passive,
    isSolid: true,
  ),
  CircleHitboxNode(
    id: const NodeId('circle'),
    name: 'sensor',
    position: const Vec2(10, 20),
    radius: 40.5,
    anchor: const NodeAnchor.custom(0.25, 0.75),
    collisionType: NodeCollisionType.inactive,
  ),
  CustomNode(
    id: const NodeId('player'),
    name: 'player',
    type: const TypeId('Player'),
    childIds: const [NodeId('circle')],
    transform: at(64, 128, w: 32, h: 48),
    fields: Overrides(const {'maxHealth': 5, 'tint': '#FF112233'}),
  ),
]);

/// One entity whose `AllFields` Behavior has an Override for every field.
String allFieldsScene({Map<String, Object?>? fields}) => sceneJson([
  RootNode(
    id: const NodeId('root'),
    childIds: const [NodeId('e'), NodeId('player')],
  ),
  EntityNode(
    id: const NodeId('e'),
    name: 'holder',
    transform: at(0, 0),
    behaviors: [
      BehaviorAttachment(
        type: const TypeId('AllFields'),
        fields: Overrides(fields ?? allOverrides),
      ),
    ],
  ),
  CustomNode(
    id: const NodeId('player'),
    name: 'player',
    type: const TypeId('Player'),
    transform: at(0, 0),
  ),
]);

/// An Override for every field of `AllFields`.
const Map<String, Object?> allOverrides = {
  'count': 4,
  'speed': 80,
  'active': false,
  'label': 'hello',
  'mode': 'b',
  'direction': [0, -1],
  'tint': '#FF8800AA',
  'icon': {'asset': 'assets/images/icon.png'},
  'sprite': {'asset': sheet},
  'effect': {'asset': fxAnim, 'animation': 'idle'},
  'target': {'ref': 'player'},
  'maybe': null,
};

/// A Scene of entities [ids] under the root, the first holding an
/// `AllFields` whose `target` points at [target].
String referenceScene(String target, {List<String> ids = const ['a', 'b']}) =>
    sceneJson([
      RootNode(
        id: const NodeId('root'),
        childIds: [for (final id in ids) NodeId(id)],
      ),
      for (final (i, id) in ids.indexed)
        EntityNode(
          id: NodeId(id),
          name: id,
          transform: at(0, 0),
          behaviors: [
            if (i == 0)
              BehaviorAttachment(
                type: const TypeId('AllFields'),
                fields: Overrides({
                  'target': {'ref': target},
                }),
              ),
          ],
        ),
    ]);
