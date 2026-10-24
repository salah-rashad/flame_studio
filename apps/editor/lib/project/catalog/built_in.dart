import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import 'manifest_parse.dart';

/// The built-in Node kinds' descriptors (`contracts/type-catalog.md`):
/// hand-written, exactly the fields the Node model carries, named as the
/// Scene format writes them. The transform is not among them — it is never
/// a FieldDescriptor and always written in full (*Q89*), so the inspector
/// renders it from `NodeTransform` for every positioned kind.
final IList<TypeDescriptor> builtInTypes = IList([
  TypeDescriptor(
    id: const TypeId('entity'),
    role: TypeRole.component,
    label: 'Entity',
    // The class behind an `entity` Node and its chain, so a Behavior whose
    // parent type is any of them fits (*Q57*).
    supertypes: ISet(const [
      'PyroEntity',
      'PositionedEntity',
      'PositionComponent',
      'Component',
    ]),
    acceptsBehaviors: true,
    builtIn: true,
    fields: const IList.empty(),
  ),
  TypeDescriptor(
    id: const TypeId('sprite'),
    role: TypeRole.component,
    label: 'Sprite',
    supertypes: const ISet.empty(),
    acceptsBehaviors: false,
    builtIn: true,
    fields: IList([
      const FieldDescriptor(
        name: 'image',
        type: FieldType.imagePath,
        nullable: false,
        tooltip: "The image's asset path.",
      ),
      const FieldDescriptor(
        name: 'region',
        type: FieldType.vector2,
        nullable: true,
        tooltip: 'The source region within the image, [x, y] pairs.',
      ),
    ]),
  ),
  TypeDescriptor(
    id: const TypeId('rectangleHitbox'),
    role: TypeRole.component,
    label: 'Rectangle hitbox',
    supertypes: const ISet.empty(),
    acceptsBehaviors: false,
    builtIn: true,
    fields: _hitboxFields,
  ),
  TypeDescriptor(
    id: const TypeId('circleHitbox'),
    role: TypeRole.component,
    label: 'Circle hitbox',
    supertypes: const ISet.empty(),
    acceptsBehaviors: false,
    builtIn: true,
    fields: _hitboxFields,
  ),
]);

/// The fields both hitbox kinds carry, named as the Scene format writes
/// them (spec 001); they share one list because they share one shape.
final IList<FieldDescriptor> _hitboxFields = IList([
  FieldDescriptor(
    name: 'collisionType',
    type: FieldType.enumeration,
    nullable: false,
    defaultValue: NodeCollisionType.active.name,
    enumValues: IList([for (final type in NodeCollisionType.values) type.name]),
    tooltip: 'How the hitbox takes part in collisions.',
  ),
  const FieldDescriptor(
    name: 'isSolid',
    type: FieldType.bool,
    nullable: false,
    defaultValue: false,
    tooltip: "Whether the hitbox is solid (Flame's isSolid).",
  ),
]);
