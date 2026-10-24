import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/panels/inspector/field_values.dart';
import 'package:pyro/panels/inspector/geometry.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import 'harness.dart';

void main() {
  final lives = field('lives', FieldType.int, min: 1, max: 5);
  final speed = field('speed', FieldType.double, defaultValue: 2.5, min: 0);

  group('clampField (FR-031)', () {
    test('limits to min and max, and rounds an int', () {
      expect(clampField(lives, 99), 5);
      expect(clampField(lives, -4), 1);
      expect(clampField(lives, 2.6), 3);
      expect(clampField(lives, 2.6), isA<int>());
      expect(clampField(speed, -1), 0);
      expect(clampField(speed, 100), 100);
      expect(clampField(speed, 1.25), 1.25);
    });
  });

  group('Custom components keep Overrides only (ADR 0003)', () {
    final node = CustomNode(
      id: const NodeId('n'),
      type: const TypeId('Hero'),
      transform: NodeTransform(),
    );

    test('an unset field reads the code default, not overridden', () {
      expect(readField(node, speed), (value: 2.5, overridden: false));
    });

    test('write sets an Override; reset removes it', () {
      final written = writeField(node, speed, 4.0) as CustomNode;
      expect(readField(written, speed), (value: 4.0, overridden: true));
      final reset = resetField(written, speed) as CustomNode;
      expect(reset.fields.isEmpty, isTrue);
      expect(readField(reset, speed).overridden, isFalse);
    });

    test('an Override equal to the default is still an Override', () {
      final written = writeField(node, speed, 2.5) as CustomNode;
      expect(readField(written, speed).overridden, isTrue);
    });

    test('other Overrides and unknown ones survive an edit', () {
      final base = node.copyWith(fields: Overrides({'ghost': 1, 'lives': 2}));
      final written = writeField(base, speed, 4.0) as CustomNode;
      expect(written.fields.values, {'ghost': 1, 'lives': 2, 'speed': 4.0});
    });
  });

  group('built-in kinds are written in full (Q89)', () {
    test('a sprite\'s image is its property, with no reset', () {
      final sprite = SpriteNode(
        id: const NodeId('s'),
        transform: NodeTransform(),
        image: const AssetPath('assets/images/a.png'),
      );
      final image = field('image', FieldType.imagePath);
      final reading = readField(sprite, image);
      expect(reading.value, {'asset': 'assets/images/a.png'});
      expect(reading.overridden, isFalse);
      final moved =
          writeField(sprite, image, {'asset': 'assets/images/b.png'})
              as SpriteNode;
      expect(moved.image, 'assets/images/b.png');
      expect(resetField(moved, image), same(moved));
    });

    test('a hitbox\'s collision type and solidity', () {
      final hitbox = RectangleHitboxNode(
        id: const NodeId('h'),
        size: const Vec2(4, 4),
      );
      final type = field('collisionType', FieldType.enumeration);
      final solid = field('isSolid', FieldType.bool);
      final changed =
          writeField(writeField(hitbox, type, 'passive'), solid, true)
              as RectangleHitboxNode;
      expect(changed.collisionType, NodeCollisionType.passive);
      expect(changed.isSolid, isTrue);
      expect(readField(changed, type).value, 'passive');
    });

    test('a sprite\'s region stays read-only', () {
      final sprite = SpriteNode(
        id: const NodeId('s'),
        transform: NodeTransform(),
        image: const AssetPath('a.png'),
      );
      expect(isEditable(sprite, field('region', FieldType.vector2)), isFalse);
      expect(isEditable(sprite, field('image', FieldType.imagePath)), isTrue);
    });
  });

  test('only the seven types the spec names are editable (FR-033)', () {
    expect(
      [
        for (final type in FieldType.values)
          if (isEditableType(type)) type,
      ],
      [
        FieldType.int,
        FieldType.double,
        FieldType.bool,
        FieldType.string,
        FieldType.enumeration,
        FieldType.vector2,
        FieldType.imagePath,
      ],
    );
  });

  test('the tooltip carries type, default and the Editable text (FR-032)', () {
    expect(fieldTooltip(speed), 'double · default 2.5 · speed tooltip');
    expect(
      fieldTooltip(field('start', FieldType.double, defaultSource: 'f()')),
      'double · default f() · start tooltip',
    );
    expect(
      fieldTooltip(
        const FieldDescriptor(
          name: 'x',
          type: FieldType.bool,
          nullable: false,
          defaultValue: true,
          tooltip: 'Whether.',
        ),
      ),
      'bool · default true · Whether.',
    );
  });

  group('geometry', () {
    test('each kind exposes the properties it has', () {
      expect(geometryOf(RootNode(id: const NodeId('r'))), isNull);
      final circle = geometryOf(
        CircleHitboxNode(id: const NodeId('c'), radius: 4),
      )!;
      expect(circle.radius, 4);
      expect(circle.size, isNull);
      expect(circle.angle, isNull);
      final rectangle = geometryOf(
        RectangleHitboxNode(id: const NodeId('h'), size: const Vec2(2, 3)),
      )!;
      expect(rectangle.scale, isNull);
      expect(rectangle.size, const Vec2(2, 3));
    });

    test('withGeometry changes only what it is given', () {
      final entity = EntityNode(
        id: const NodeId('e'),
        name: 'e',
        transform: NodeTransform(
          position: const Vec2(1, 2),
          size: const Vec2(3, 4),
          angle: 0.5,
        ),
      );
      final moved =
          withGeometry(entity, position: const Vec2(9, 9)) as EntityNode;
      expect(moved.transform.position, const Vec2(9, 9));
      expect(moved.transform.size, const Vec2(3, 4));
      expect(moved.transform.angle, 0.5);
      expect(moved.name, 'e');
    });
  });
}
