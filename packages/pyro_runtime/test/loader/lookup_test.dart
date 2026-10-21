import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import '../support/loader_fixtures.dart';
import '../support/scene_text.dart';
import '../support/test_registry.dart';

EntityNode _entity(
  String id, {
  String? name,
  List<String> children = const [],
  List<String> tags = const [],
}) => EntityNode(
  id: NodeId(id),
  name: name,
  tags: tags,
  childIds: [for (final child in children) NodeId(child)],
  transform: at(0, 0),
);

CustomNode _enemy(String id, String name, {List<String> children = const []}) =>
    CustomNode(
      id: NodeId(id),
      name: name,
      type: const TypeId('Enemy'),
      childIds: [for (final child in children) NodeId(child)],
      transform: at(0, 0),
    );

/// root → arena → boss1, inner → boss3; root → cave → boss2; player;
/// three entities tagged `enemy` (one unnamed); a Node named `a/b`.
String _lookups() => sceneJson([
  RootNode(
    id: const NodeId('root'),
    childIds: const [
      NodeId('arena'),
      NodeId('cave'),
      NodeId('player'),
      NodeId('t1'),
      NodeId('slash'),
    ],
  ),
  _entity('arena', name: 'arena', children: ['boss1', 'inner']),
  _enemy('boss1', 'boss'),
  _entity('inner', name: 'inner', children: ['boss3']),
  _enemy('boss3', 'boss'),
  _entity('cave', name: 'cave', children: ['boss2']),
  _enemy('boss2', 'boss'),
  CustomNode(
    id: const NodeId('player'),
    name: 'player',
    type: const TypeId('Player'),
    transform: at(0, 0),
  ),
  _entity('t1', name: 'grunt', tags: ['enemy'], children: ['t2']),
  _entity('t2', tags: ['enemy'], children: ['t3']),
  _entity('t3', name: 'brute', tags: ['enemy', 'big']),
  _entity('slash', name: 'a/b', tags: ['odd']),
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PyroScene scene;

  setUp(() async {
    // Lookups work before the Scene is added to a game (US3 #6).
    scene = await PyroScene.load(
      scenePath,
      registry: testRegistry,
      assets: await sourceFor(_lookups()),
    );
  });

  Matcher stateError(List<String> mentions) => throwsA(
    isA<StateError>().having(
      (e) => e.message,
      'message',
      allOf([startsWith(scenePath), for (final m in mentions) contains(m)]),
    ),
  );

  test('#1 find by a unique name', () {
    expect(scene.find<Player>('player'), isA<Player>());
    expect(scene.find('player'), same(scene.find<Player>('player')));
  });

  test('#2 an ambiguous name lists every path and points to findAll', () {
    expect(
      () => scene.find('boss'),
      stateError([
        '3 Nodes match "boss"',
        'arena/boss',
        'arena/inner/boss',
        'cave/boss',
        'findAll',
      ]),
    );
  });

  test('#3 a path matches a Node and its nearest ancestors', () {
    final arenaBoss = scene.find<Enemy>('arena/boss');
    final innerBoss = scene.find<Enemy>('inner/boss');
    expect(arenaBoss, isNot(same(innerBoss)));
    expect(scene.find<Enemy>('arena/inner/boss'), same(innerBoss));
    expect(scene.find<Enemy>('cave/boss'), isNot(same(arenaBoss)));
  });

  test('#3 a leading / anchors the path at the root', () {
    expect(scene.find<Enemy>('/arena/boss'), same(scene.find('arena/boss')));
    expect(() => scene.find('/inner/boss'), stateError(['no Node matches']));
  });

  test('#4 no match names the Scene and the query', () {
    expect(() => scene.find('nobody'), stateError(['"nobody"']));
  });

  test('#4 a match of the wrong type names both types', () {
    expect(
      () => scene.find<Player>('arena'),
      stateError(['"arena" (arena)', 'PyroEntity', 'Player']),
    );
  });

  test('ambiguity is decided by name, before the type', () {
    expect(() => scene.find<Enemy>('boss'), stateError(['3 Nodes match']));
  });

  test('#5 findAll by tag, in tree order, unnamed Nodes included', () {
    final enemies = scene.findAll(tag: 'enemy');
    expect(enemies, hasLength(3));
    expect(enemies.first, same(scene.find('grunt')));
    expect(enemies.last, same(scene.find('brute')));
  });

  test('#5 findAll combines name, tag and type, and may be empty', () {
    expect(scene.findAll<Enemy>(name: 'boss'), hasLength(3));
    expect(scene.findAll<Player>(name: 'boss'), isEmpty);
    expect(scene.findAll(name: 'x'), isEmpty);
    expect(scene.findAll(tag: 'enemy', name: 'brute'), hasLength(1));
    expect(scene.findAll<PositionComponent>(), hasLength(11));
  });

  test('a Node named with / is found by tag or type, not by name', () {
    expect(() => scene.find('a/b'), stateError(['no Node matches']));
    expect(scene.findAll(tag: 'odd'), hasLength(1));
  });

  testWithFlameGame('lookups work the same once mounted', (game) async {
    final before = scene.find<Enemy>('arena/boss');
    await game.ensureAdd(scene);
    await game.ready();
    expect(scene.find<Enemy>('arena/boss'), same(before));
    expect(scene.findAll(tag: 'enemy'), hasLength(3));
  });
}
