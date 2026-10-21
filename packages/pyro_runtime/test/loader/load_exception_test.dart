import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

void main() {
  test('names the Scene, Node, field, asset, message and cause', () {
    final error = SceneLoadException(
      const AssetPath('assets/scenes/level1.scene.json'),
      "the animation \"run\" isn't in the file",
      nodeId: const NodeId('3f1c'),
      nodeName: 'goblin_1',
      typeId: const TypeId('Patrol'),
      field: 'hitEffect',
      asset: const AssetPath('assets/anims/goblin.anim.json'),
      cause: StateError('boom'),
      causeStackTrace: StackTrace.current,
    );
    final text = error.toString();
    expect(
      text,
      startsWith(
        'assets/scenes/level1.scene.json: Node "goblin_1" (3f1c), '
        'Patrol.hitEffect, asset assets/anims/goblin.anim.json: ',
      ),
    );
    expect(text, contains('"run"'));
    expect(text, endsWith('\nCaused by: Bad state: boom'));
  });

  test('leaves out every part that is null', () {
    const error = SceneLoadException(
      AssetPath('assets/scenes/a.scene.json'),
      "couldn't be read",
    );
    expect(error.toString(), "assets/scenes/a.scene.json: couldn't be read");
  });

  test('names an unnamed Node by ID, and a Type ID without a field', () {
    const error = SceneLoadException(
      AssetPath('a.scene.json'),
      'missing',
      nodeId: NodeId('e1'),
      typeId: TypeId('Patrol'),
    );
    expect(error.toString(), 'a.scene.json: Node (e1), Patrol: missing');
  });
}
