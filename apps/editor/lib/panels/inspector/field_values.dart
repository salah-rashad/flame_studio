import 'package:pyro/project/project.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

/// A Field's value in its Scene written form, and whether the Scene sets it.
typedef FieldReading = ({Object? value, bool overridden});

/// The Field types the inspector edits this phase (FR-030); the rest show
/// read-only and round-trip untouched (FR-033).
bool isEditableType(FieldType type) => switch (type) {
  FieldType.int ||
  FieldType.double ||
  FieldType.bool ||
  FieldType.string ||
  FieldType.enumeration ||
  FieldType.vector2 ||
  FieldType.imagePath => true,
  _ => false,
};

/// Whether [field] of [node] is edited by a row at all: the sprite's
/// `region` is four numbers in the file, which the `Vector2` editor can't
/// write, so it stays read-only.
bool isEditable(Node node, FieldDescriptor field) =>
    isEditableType(field.type) &&
    !(node is SpriteNode && field.name == 'region');

/// Whether [field] is a user type's Editable field, which the Scene stores
/// as an Override (ADR 0003). The built-in kinds' properties are always
/// written in full instead (*Q89*), so they have no marker and no reset.
bool storesOverrides(Node node) => node is CustomNode;

/// [field]'s current value on [node]: the Override or the built-in
/// property, else the Manifest's evaluated default.
FieldReading readField(Node node, FieldDescriptor field) {
  switch (node) {
    case CustomNode():
      return node.fields.contains(field.name)
          ? (value: node.fields[field.name], overridden: true)
          : (value: field.defaultValue, overridden: false);
    case SpriteNode():
      return (
        value: switch (field.name) {
          'image' => {'asset': node.image},
          'region' when node.region != null => [
            node.region!.position.x,
            node.region!.position.y,
            node.region!.size.x,
            node.region!.size.y,
          ],
          _ => null,
        },
        overridden: false,
      );
    case RectangleHitboxNode():
      return (
        value: _hitboxValue(field, node.collisionType, node.isSolid),
        overridden: false,
      );
    case CircleHitboxNode():
      return (
        value: _hitboxValue(field, node.collisionType, node.isSolid),
        overridden: false,
      );
    case RootNode() || EntityNode() || UnknownNode():
      return (value: null, overridden: false);
  }
}

Object? _hitboxValue(
  FieldDescriptor field,
  NodeCollisionType collisionType,
  bool isSolid,
) => switch (field.name) {
  'collisionType' => collisionType.name,
  'isSolid' => isSolid,
  _ => null,
};

/// [node] with [field] set to [value] (in Scene written form): an Override
/// on a Custom component, the property itself on a built-in kind.
Node writeField(Node node, FieldDescriptor field, Object? value) {
  switch (node) {
    case CustomNode():
      return node.copyWith(fields: node.fields.put(field.name, value));
    case SpriteNode() when field.name == 'image':
      final ref = AssetRef.fromJson(value);
      return ref == null ? node : node.copyWith(image: ref.path);
    case RectangleHitboxNode():
      return node.copyWith(
        collisionType: field.name == 'collisionType'
            ? NodeCollisionType.values.byName(value! as String)
            : null,
        isSolid: field.name == 'isSolid' ? value! as bool : null,
      );
    case CircleHitboxNode():
      return node.copyWith(
        collisionType: field.name == 'collisionType'
            ? NodeCollisionType.values.byName(value! as String)
            : null,
        isSolid: field.name == 'isSolid' ? value! as bool : null,
      );
    default:
      return node;
  }
}

/// The Behaviors attached to [node]: only an entity or a Custom component
/// holds any.
List<BehaviorAttachment> behaviorsOf(Node node) => switch (node) {
  EntityNode(:final behaviors) => behaviors,
  CustomNode(:final behaviors) => behaviors,
  _ => const [],
};

/// [node] with its Behaviors replaced by [behaviors].
Node withBehaviors(Node node, List<BehaviorAttachment> behaviors) =>
    switch (node) {
      EntityNode() => node.copyWith(behaviors: behaviors),
      CustomNode() => node.copyWith(behaviors: behaviors),
      _ => node,
    };

/// [field]'s current value on a Behavior: its Override, else the Manifest's
/// evaluated default.
FieldReading readBehaviorField(
  BehaviorAttachment behavior,
  FieldDescriptor field,
) => behavior.fields.contains(field.name)
    ? (value: behavior.fields[field.name], overridden: true)
    : (value: field.defaultValue, overridden: false);

/// [node] with the Behavior at [index] changed by [change]; the Behavior's
/// other values, and its unknown keys, are kept.
Node _withBehavior(
  Node node,
  int index,
  BehaviorAttachment Function(BehaviorAttachment behavior) change,
) {
  final behaviors = behaviorsOf(node);
  if (index < 0 || index >= behaviors.length) return node;
  return withBehaviors(node, [
    for (var i = 0; i < behaviors.length; i++)
      i == index ? change(behaviors[i]) : behaviors[i],
  ]);
}

/// [node] with [field] of its Behavior at [index] overridden to [value].
Node writeBehaviorField(
  Node node,
  int index,
  FieldDescriptor field,
  Object? value,
) => _withBehavior(
  node,
  index,
  (behavior) =>
      behavior.copyWith(fields: behavior.fields.put(field.name, value)),
);

/// [node] with the Override of [field] on its Behavior at [index] removed
/// (*Reset to default*).
Node resetBehaviorField(Node node, int index, FieldDescriptor field) =>
    _withBehavior(
      node,
      index,
      (behavior) =>
          behavior.copyWith(fields: behavior.fields.reset(field.name)),
    );

/// [node] with [field]'s Override removed, so the code default applies
/// again (*Reset to default*, ADR 0003). Built-in properties have no
/// default to return to, so they come back unchanged.
Node resetField(Node node, FieldDescriptor field) => switch (node) {
  CustomNode() => node.copyWith(fields: node.fields.reset(field.name)),
  _ => node,
};

/// [value] limited to [field]'s `min`/`max`, and rounded for an `int`
/// field: no out-of-range number is ever written (FR-031).
num clampField(FieldDescriptor field, num value) {
  var result = value.toDouble();
  final min = field.min;
  final max = field.max;
  if (min != null && result < min) result = min;
  if (max != null && result > max) result = max;
  return field.type == FieldType.int ? result.round() : result;
}

/// The number [value] holds, or null when it isn't one.
double? numberOf(Object? value) => value is num ? value.toDouble() : null;

/// A `Vector2` Field's `[x, y]`, or null when [value] isn't one.
(double, double)? vectorOf(Object? value) => switch (value) {
  [final num x, final num y] => (x.toDouble(), y.toDouble()),
  _ => null,
};

/// The path an image-path Field holds, or null.
String? imagePathOf(Object? value) => AssetRef.fromJson(value)?.path;

/// What a non-constant default says in place of a value (§7.3): the
/// initializer's source text, when the Manifest could not evaluate it.
String? defaultSourceOf(FieldDescriptor field) =>
    field.defaultValue == null ? field.defaultSource : null;

/// The tooltip of [field]'s row: type · default · the `@Editable(tooltip:)`
/// text (FR-032).
String fieldTooltip(FieldDescriptor field) {
  final fallback = field.defaultValue != null
      ? '${field.defaultValue}'
      : field.defaultSource;
  return [
    field.type.name,
    if (fallback != null) 'default $fallback',
    ?field.tooltip,
  ].join(' · ');
}

/// A value to start an Override from when the code default can't be shown
/// as a value — a non-constant default, or a nullable `null`.
Object? seedValue(FieldDescriptor field) => switch (field.type) {
  FieldType.int || FieldType.double => clampField(field, 0),
  FieldType.bool => false,
  FieldType.string => '',
  FieldType.enumeration => field.enumValues?.firstOrNull,
  FieldType.vector2 => [0.0, 0.0],
  _ => null,
};
