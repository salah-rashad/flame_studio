import 'dart:async';
import 'dart:io' show FileSystemEvent;
import 'dart:typed_data';
import 'dart:ui';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:file/memory.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/painting.dart' show decodeImageFromList;
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro/viewport/viewport.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import 'disk_assets_test.dart' show png;

const root = '/project';
const hero = AssetPath('assets/images/hero.png');
const goblinPreview = AssetPath('assets/images/goblin_preview.png');

TypeCatalog catalogWith(Iterable<TypeDescriptor> types) => TypeCatalog(
  types: IMap({for (final type in types) type.id: type}),
  problems: const IList.empty(),
  origin: const ManifestAbsent(),
);

TypeDescriptor custom(String id, {AssetPath? preview}) => TypeDescriptor(
  id: TypeId(id),
  role: TypeRole.component,
  label: id,
  supertypes: const ISet.empty(),
  acceptsBehaviors: false,
  preview: preview,
  builtIn: false,
  fields: const IList.empty(),
);

/// A `TextComponent` subclass with a `message` and a `color` Field, like
/// the example's Banner.
TypeDescriptor banner() => custom('Banner').copyWith(
  supertypes: ISet(const ['TextComponent', 'PositionComponent']),
  fields: IList(const [
    FieldDescriptor(
      name: 'message',
      type: FieldType.string,
      nullable: false,
      defaultValue: 'Pyro',
    ),
    FieldDescriptor(name: 'color', type: FieldType.color, nullable: false),
  ]),
);

void main() {
  late MemoryFileSystem fs;
  late DiskAssetSource assets;
  late PreviewContext context;

  // The files hold just their size; the decoder hands out clones of
  // images made up front, so loads finish within the event queue and the
  // tests never wait on the engine's clock (constitution V).
  final images = <String, Image>{};

  setUpAll(() async {
    for (final (w, h) in [(4, 2), (8, 8), (6, 6), (3, 3)]) {
      images['${w}x$h'] = await decodeImageFromList(await png(w, h));
    }
  });

  Future<Image> decode(Uint8List bytes) async =>
      images['${bytes[0]}x${bytes[1]}']!.clone();

  Future<void> write(AssetPath path, int width, int height) async {
    final file = fs.file('$root/$path');
    await file.parent.create(recursive: true);
    await file.writeAsBytes([width, height]);
  }

  setUp(() async {
    fs = MemoryFileSystem.test();
    await write(hero, 4, 2);
    assets = DiskAssetSource(
      fileSystem: fs,
      root: root,
      watch: (_) => const Stream<FileSystemEvent>.empty(),
      decode: decode,
    );
    context = PreviewContext(
      assets: assets,
      catalog: catalogWith([custom('goblin')]),
    );
  });

  tearDown(() => assets.dispose());

  /// Lets the image loads land.
  Future<void> settle() => pumpEventQueue();

  SpriteNode spriteNode({AssetPath image = hero, SpriteRegion? region}) =>
      SpriteNode(
        id: const NodeId('s'),
        transform: NodeTransform(
          position: const Vec2(10, 20),
          size: const Vec2(16, 8),
        ),
        image: image,
        region: region,
      );

  testWithFlameGame('an entity is a group at its transform', (game) async {
    final node = EntityNode(
      id: const NodeId('e'),
      transform: NodeTransform(
        position: const Vec2(5, 6),
        scale: const Vec2(2, 2),
        angle: 0.5,
        anchor: NodeAnchor.center,
      ),
    );
    final component = previewOf(node, context);
    await game.world.add(component);
    await game.ready();
    expect(component, isA<EntityPreview>());
    expect(component.position, Vector2(5, 6));
    expect(component.scale, Vector2(2, 2));
    expect(component.angle, 0.5);
    expect(component.anchor, Anchor.center);
  });

  testWithFlameGame('a sprite draws its disk image, pixel-exact', (game) async {
    final component = previewOf(spriteNode(), context) as SpritePreview;
    await game.world.add(component);
    await game.ready();
    await settle();
    expect(component.sprite!.image.width, 4);
    expect(component.paint.filterQuality, FilterQuality.none);
    expect(component.position, Vector2(10, 20));
    expect(component.size, Vector2(16, 8));
    expect(component.assetPaths, {hero});
  });

  testWithFlameGame('a sprite region crops the image', (game) async {
    final component =
        previewOf(
              spriteNode(
                region: const SpriteRegion(
                  position: Vec2(1, 0),
                  size: Vec2(2, 2),
                ),
              ),
              context,
            )
            as SpritePreview;
    await game.world.add(component);
    await settle();
    expect(component.sprite!.srcPosition, Vector2(1, 0));
    expect(component.sprite!.srcSize, Vector2(2, 2));
  });

  testWithFlameGame('a missing image shows the error state, not a crash', (
    game,
  ) async {
    final component =
        previewOf(
              spriteNode(image: const AssetPath('assets/images/nope.png')),
              context,
            )
            as SpritePreview;
    await game.world.add(component);
    await settle();
    expect(component.failed, isTrue);
    expect(component.sprite, isNull);
    game.render(PictureRecorder().let(Canvas.new));
  });

  testWithFlameGame('a patch swaps the image in place', (game) async {
    const other = AssetPath('assets/images/other.png');
    await write(other, 8, 8);
    final component = previewOf(spriteNode(), context) as SpritePreview;
    await game.world.add(component);
    await settle();
    final first = component.sprite!.image;
    component.patch(spriteNode(image: other), context);
    await settle();
    expect(component.sprite!.image.width, 8);
    expect(component.assetPaths, {other});
    assets.invalidate({hero});
    expect(first.debugDisposed, isTrue, reason: 'nothing draws it any more');
  });

  testWithFlameGame('a reload after a file change shows the new pixels', (
    game,
  ) async {
    final component = previewOf(spriteNode(), context) as SpritePreview;
    await game.world.add(component);
    await settle();
    await write(hero, 6, 6);
    assets.invalidate({hero});
    await component.reloadAssets(context);
    expect(component.sprite!.image.width, 6);
  });

  testWithFlameGame('hitboxes draw as outlines at their geometry', (
    game,
  ) async {
    final rect =
        previewOf(
              RectangleHitboxNode(
                id: const NodeId('r'),
                position: const Vec2(1, 2),
                size: const Vec2(10, 4),
              ),
              context,
            )
            as RectangleHitboxPreview;
    final circle =
        previewOf(
              CircleHitboxNode(
                id: const NodeId('c'),
                position: const Vec2(0, 0),
                radius: 5,
              ),
              context,
            )
            as CircleHitboxPreview;
    await game.world.addAll([rect, circle]);
    await game.ready();
    expect(rect.position, Vector2(1, 2));
    expect(rect.size, Vector2(10, 4));
    expect(circle.size, Vector2(10, 10));
    expect(circle.containsLocalPoint(Vector2(5, 5)), isTrue);
    expect(circle.containsLocalPoint(Vector2(0.5, 0.5)), isFalse);
  });

  testWithFlameGame('a Custom component is a placeholder labelled by Type ID', (
    game,
  ) async {
    final component =
        previewOf(
              CustomNode(
                id: const NodeId('g'),
                type: const TypeId('goblin'),
                transform: NodeTransform(),
              ),
              context,
            )
            as PlaceholderPreview;
    await game.world.add(component);
    await game.ready();
    expect(component.label, 'goblin');
    expect(component.missing, isFalse);
    expect(component.size, Vector2.all(PlaceholderPreview.defaultSide));
    component.showLabel = true;
    game.render(PictureRecorder().let(Canvas.new));
  });

  testWithFlameGame(
    'a labelled placeholder still draws after it is reparented',
    (game) async {
      final component =
          previewOf(
                CustomNode(
                  id: const NodeId('g'),
                  type: const TypeId('goblin'),
                  transform: NodeTransform(),
                ),
                context,
              )
              as PlaceholderPreview;
      final first = PositionComponent();
      final second = PositionComponent();
      await game.world.addAll([first, second]);
      await first.add(component);
      await game.ready();
      component.showLabel = true;
      game.render(PictureRecorder().let(Canvas.new));
      // Flame removes the component and mounts it again under the new
      // parent; its label must lay out again rather than reuse a freed one.
      component.parent = second;
      game.update(0);
      await game.ready();
      game.render(PictureRecorder().let(Canvas.new));
    },
  );

  testWithFlameGame('a Custom component draws its Manifest preview image', (
    game,
  ) async {
    await write(goblinPreview, 3, 3);
    final withPreview = PreviewContext(
      assets: assets,
      catalog: catalogWith([custom('goblin', preview: goblinPreview)]),
    );
    final component = previewOf(
      CustomNode(
        id: const NodeId('g'),
        type: const TypeId('goblin'),
        transform: NodeTransform(),
      ),
      withPreview,
    );
    await game.world.add(component);
    await settle();
    expect(component.assetPaths, {goblinPreview});
  });

  group('a text component', () {
    CustomNode bannerNode({Overrides fields = const Overrides.empty()}) =>
        CustomNode(
          id: const NodeId('t'),
          type: const TypeId('Banner'),
          transform: NodeTransform(position: const Vec2(5, 6)),
          fields: fields,
        );

    PlaceholderPreview preview(CustomNode node) =>
        previewOf(
              node,
              PreviewContext(assets: assets, catalog: catalogWith([banner()])),
            )
            as PlaceholderPreview;

    test('shows its Field default', () {
      final component = preview(bannerNode());
      expect(component.text, 'Pyro');
      expect(component.textColor, const Color(0xFFFFFFFF));
    });

    test('shows its Overrides, and sizes itself to the text', () {
      final component = preview(
        bannerNode(
          fields: Overrides({'message': 'Hello', 'color': '#FFFF0000'}),
        ),
      );
      expect(component.text, 'Hello');
      expect(component.textColor, const Color(0xFFFF0000));
      expect(component.size.x, greaterThan(PlaceholderPreview.defaultSide));
    });

    test('follows a patch', () {
      final component = preview(bannerNode());
      final before = component.size.x;
      component.patch(
        bannerNode(fields: Overrides({'message': 'Hello from Pyro'})),
        PreviewContext(assets: assets, catalog: catalogWith([banner()])),
      );
      expect(component.text, 'Hello from Pyro');
      expect(component.size.x, greaterThan(before));
    });

    test('a blank or non-text Override falls back to the placeholder', () {
      expect(
        preview(bannerNode(fields: Overrides({'message': ''}))).text,
        isNull,
      );
      expect(
        preview(bannerNode(fields: Overrides({'message': 3}))).text,
        isNull,
      );
    });

    test('other Custom components stay placeholders', () {
      final component =
          previewOf(
                CustomNode(
                  id: const NodeId('g'),
                  type: const TypeId('goblin'),
                  transform: NodeTransform(),
                ),
                context,
              )
              as PlaceholderPreview;
      expect(component.text, isNull);
    });

    testWithFlameGame('draws without error', (game) async {
      final component = preview(bannerNode());
      await game.world.add(component);
      await game.ready();
      game.render(PictureRecorder().let(Canvas.new));
    });
  });

  testWithFlameGame('a type missing from the catalog is a Missing component', (
    game,
  ) async {
    final custom =
        previewOf(
              CustomNode(
                id: const NodeId('x'),
                type: const TypeId('gone'),
                transform: NodeTransform(),
              ),
              context,
            )
            as PlaceholderPreview;
    final unknown =
        previewOf(UnknownNode(id: const NodeId('u'), kind: 'tilemap'), context)
            as PlaceholderPreview;
    expect(custom.missing, isTrue);
    expect(unknown.missing, isTrue);
    expect(unknown.label, 'tilemap');
  });
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
