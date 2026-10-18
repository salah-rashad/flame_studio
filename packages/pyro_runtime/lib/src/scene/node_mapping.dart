import 'errors.dart';
import 'node.dart';
import 'overrides.dart';
import 'values.dart';

/// Builds the Node with ID [id] from its JSON object, checking every known
/// key (data-model.md, "Validation on read").
///
/// Keys this version doesn't know are kept in `Node.extra`,
/// `NodeTransform.extra` or `propsExtra`, depending on where they appear
/// (FR-017). Throws [InvalidNode] naming the Node and the key.
Node nodeFromJson(NodeId id, Object? json) {
  final context = _NodeContext(id);
  if (id.isEmpty) context.fail(null, 'Node IDs must not be empty');
  if (json is! Map<String, Object?>) {
    context.fail(null, 'a Node must be a JSON object');
  }
  final node = _JsonObject(json, context, '');
  final kind = node.string('kind');
  final childIds = [
    for (final child in node.stringList('childIds')) NodeId(child),
  ];

  if (kind == 'root') {
    return RootNode(id: id, childIds: childIds, extra: node.rest());
  }
  if (!_knownKinds.contains(kind)) {
    // Keep a Node of an unknown kind whole; read its name and tags only when
    // they have the expected types.
    final name = json['name'] is String ? node.optionalString('name') : null;
    final tags = _isStringList(json['tags'])
        ? node.stringList('tags')
        : const <String>[];
    return UnknownNode(
      id: id,
      childIds: childIds,
      name: name,
      tags: tags,
      kind: kind,
      extra: node.rest(),
    );
  }

  final name = context.name = node.optionalString('name');
  final tags = node.stringList('tags');
  switch (kind) {
    case 'entity':
      final transform = _transform(node.object('transform'));
      return EntityNode(
        id: id,
        childIds: childIds,
        name: name,
        tags: tags,
        transform: transform,
        behaviors: _behaviors(node),
        extra: node.rest(),
      );
    case 'sprite':
      final transform = _transform(node.object('transform'));
      final props = node.object('props');
      final image = AssetPath(props.string('image', nonEmpty: true));
      final srcPosition = props.optionalVec2('srcPosition');
      final srcSize = props.optionalVec2('srcSize', nonNegative: true);
      if ((srcPosition == null) != (srcSize == null)) {
        props.fail(
          srcPosition == null ? 'srcPosition' : 'srcSize',
          'srcPosition and srcSize must both be present or both be absent',
        );
      }
      return SpriteNode(
        id: id,
        childIds: childIds,
        name: name,
        tags: tags,
        transform: transform,
        image: image,
        region: srcPosition == null
            ? null
            : SpriteRegion(position: srcPosition, size: srcSize!),
        propsExtra: props.rest(),
        extra: node.rest(),
      );
    case 'rectangleHitbox':
      final props = node.object('props');
      return RectangleHitboxNode(
        id: id,
        childIds: childIds,
        name: name,
        tags: tags,
        position: props.vec2('position'),
        size: props.vec2('size', nonNegative: true),
        angle: props.number('angle'),
        anchor: props.anchor('anchor'),
        collisionType: props.collisionType('collisionType'),
        isSolid: props.boolean('isSolid'),
        propsExtra: props.rest(),
        extra: node.rest(),
      );
    case 'circleHitbox':
      final props = node.object('props');
      return CircleHitboxNode(
        id: id,
        childIds: childIds,
        name: name,
        tags: tags,
        position: props.vec2('position'),
        radius: props.number('radius', nonNegative: true),
        anchor: props.anchor('anchor'),
        collisionType: props.collisionType('collisionType'),
        isSolid: props.boolean('isSolid'),
        propsExtra: props.rest(),
        extra: node.rest(),
      );
    case 'custom':
      final type = context.type = TypeId(node.string('type', nonEmpty: true));
      final transform = _transform(node.object('transform'));
      return CustomNode(
        id: id,
        childIds: childIds,
        name: name,
        tags: tags,
        type: type,
        transform: transform,
        fields: _overrides(node),
        behaviors: _behaviors(node),
        extra: node.rest(),
      );
  }
  throw StateError('Unhandled Node kind "$kind"');
}

/// The optional `behaviors` list; each Behavior needs a non-empty `type`.
List<BehaviorAttachment> _behaviors(_JsonObject node) => [
  for (final behavior in node.objectList('behaviors'))
    BehaviorAttachment(
      type: TypeId(behavior.string('type', nonEmpty: true)),
      fields: _overrides(behavior),
      extra: behavior.rest(),
    ),
];

/// The optional `fields` object, kept as JSON values without interpreting
/// them (FR-011).
Overrides _overrides(_JsonObject owner) {
  final fields = owner.optionalMap('fields');
  return fields == null || fields.isEmpty
      ? const Overrides.empty()
      : Overrides(fields);
}

Map<String, Object?> _behaviorToJson(BehaviorAttachment behavior) => {
  ...behavior.extra,
  'type': behavior.type,
  if (!behavior.fields.isEmpty) 'fields': behavior.fields.values,
};

/// The JSON object for [node], ready for the canonical writer. Empty
/// `childIds` and `tags` and a null name are left out; built-in properties
/// are always written in full (FR-013).
Map<String, Object?> nodeToJson(Node node) {
  final json = <String, Object?>{...node.extra};
  if (node.childIds.isNotEmpty) json['childIds'] = node.childIds;
  if (node is NamedNode) {
    if (node.name != null) json['name'] = node.name;
    if (node.tags.isNotEmpty) json['tags'] = node.tags;
  }
  switch (node) {
    case RootNode():
      json['kind'] = 'root';
    case EntityNode():
      json['kind'] = 'entity';
      json['transform'] = _transformToJson(node.transform);
      if (node.behaviors.isNotEmpty) {
        json['behaviors'] = [
          for (final b in node.behaviors) _behaviorToJson(b),
        ];
      }
    case SpriteNode():
      json['kind'] = 'sprite';
      json['transform'] = _transformToJson(node.transform);
      final region = node.region;
      json['props'] = <String, Object?>{
        ...node.propsExtra,
        'image': node.image,
        if (region != null) 'srcPosition': _vec2ToJson(region.position),
        if (region != null) 'srcSize': _vec2ToJson(region.size),
      };
    case RectangleHitboxNode():
      json['kind'] = 'rectangleHitbox';
      json['props'] = <String, Object?>{
        ...node.propsExtra,
        'anchor': _anchorToJson(node.anchor),
        'angle': node.angle,
        'collisionType': node.collisionType.name,
        'isSolid': node.isSolid,
        'position': _vec2ToJson(node.position),
        'size': _vec2ToJson(node.size),
      };
    case CircleHitboxNode():
      json['kind'] = 'circleHitbox';
      json['props'] = <String, Object?>{
        ...node.propsExtra,
        'anchor': _anchorToJson(node.anchor),
        'collisionType': node.collisionType.name,
        'isSolid': node.isSolid,
        'position': _vec2ToJson(node.position),
        'radius': node.radius,
      };
    case CustomNode():
      json['kind'] = 'custom';
      json['type'] = node.type;
      json['transform'] = _transformToJson(node.transform);
      if (!node.fields.isEmpty) json['fields'] = node.fields.values;
      if (node.behaviors.isNotEmpty) {
        json['behaviors'] = [
          for (final b in node.behaviors) _behaviorToJson(b),
        ];
      }
    case UnknownNode():
      json['kind'] = node.kind;
  }
  return json;
}

const Set<String> _knownKinds = {
  'entity',
  'sprite',
  'rectangleHitbox',
  'circleHitbox',
  'custom',
};

bool _isStringList(Object? value) =>
    value is List<Object?> && value.every((e) => e is String);

NodeTransform _transform(_JsonObject t) => NodeTransform(
  position: t.vec2('position'),
  size: t.vec2('size', nonNegative: true),
  scale: t.vec2('scale'),
  angle: t.number('angle'),
  anchor: t.anchor('anchor'),
  extra: t.rest(),
);

Map<String, Object?> _transformToJson(NodeTransform t) => {
  ...t.extra,
  'anchor': _anchorToJson(t.anchor),
  'angle': t.angle,
  'position': _vec2ToJson(t.position),
  'scale': _vec2ToJson(t.scale),
  'size': _vec2ToJson(t.size),
};

List<double> _vec2ToJson(Vec2 v) => [v.x, v.y];

Object _anchorToJson(NodeAnchor anchor) => anchor.name ?? [anchor.x, anchor.y];

/// What error messages say about the Node being read.
final class _NodeContext {
  _NodeContext(this.id);

  final NodeId id;
  String? name;
  TypeId? type;

  Never fail(String? key, String reason) =>
      throw InvalidNode(id, reason, nodeName: name, typeId: type, key: key);
}

/// A JSON object being read, tracking which keys were used so the rest can
/// be kept as unknown keys.
final class _JsonObject {
  _JsonObject(this._map, this._context, this._path);

  final Map<String, Object?> _map;
  final _NodeContext _context;
  final String _path;
  final Set<String> _used = {};

  String _keyPath(String key) => _path.isEmpty ? key : '$_path.$key';

  Never fail(String key, String reason) => _context.fail(_keyPath(key), reason);

  Object? _take(String key) {
    _used.add(key);
    return _map[key];
  }

  Object? _require(String key) {
    if (!_map.containsKey(key)) fail(key, 'is missing');
    return _take(key);
  }

  String string(String key, {bool nonEmpty = false}) {
    final value = _require(key);
    if (value is! String) fail(key, 'must be a string');
    if (nonEmpty && value.isEmpty) fail(key, 'must not be empty');
    return value;
  }

  String? optionalString(String key) {
    if (!_map.containsKey(key)) return null;
    final value = _take(key);
    if (value is! String) fail(key, 'must be a string');
    return value;
  }

  double number(String key, {bool nonNegative = false}) {
    final value = _require(key);
    if (value is! num) fail(key, 'must be a number');
    if (nonNegative && value < 0) fail(key, 'must not be negative');
    return value.toDouble();
  }

  bool boolean(String key) {
    final value = _require(key);
    if (value is! bool) fail(key, 'must be true or false');
    return value;
  }

  Vec2 vec2(String key, {bool nonNegative = false}) =>
      _toVec2(key, _require(key), nonNegative: nonNegative);

  Vec2? optionalVec2(String key, {bool nonNegative = false}) =>
      _map.containsKey(key)
      ? _toVec2(key, _take(key), nonNegative: nonNegative)
      : null;

  Vec2 _toVec2(String key, Object? value, {required bool nonNegative}) {
    if (value is! List<Object?> ||
        value.length != 2 ||
        value[0] is! num ||
        value[1] is! num) {
      fail(key, 'must be [x, y] with two numbers');
    }
    final x = (value[0]! as num).toDouble();
    final y = (value[1]! as num).toDouble();
    if (nonNegative && (x < 0 || y < 0)) fail(key, 'must not be negative');
    return Vec2(x, y);
  }

  NodeAnchor anchor(String key) {
    final value = _require(key);
    if (value is String) {
      return NodeAnchor.byName(value) ??
          fail(key, 'unknown anchor "$value"; use a named anchor or [x, y]');
    }
    if (value is List<Object?>) {
      final point = _toVec2(key, value, nonNegative: false);
      return NodeAnchor.custom(point.x, point.y);
    }
    fail(key, 'must be an anchor name or [x, y]');
  }

  NodeCollisionType collisionType(String key) {
    final value = _require(key);
    for (final type in NodeCollisionType.values) {
      if (type.name == value) return type;
    }
    fail(key, 'must be "active", "passive" or "inactive", found "$value"');
  }

  /// An optional list of strings; absent means empty.
  List<String> stringList(String key) {
    if (!_map.containsKey(key)) return const [];
    final value = _take(key);
    if (value is! List<Object?>) fail(key, 'must be a list of strings');
    for (var i = 0; i < value.length; i++) {
      if (value[i] is! String) fail('$key[$i]', 'must be a string');
    }
    return value.cast<String>();
  }

  _JsonObject object(String key) {
    final value = _require(key);
    if (value is! Map<String, Object?>) fail(key, 'must be a JSON object');
    return _JsonObject(value, _context, _keyPath(key));
  }

  /// An optional JSON object, returned as it is.
  Map<String, Object?>? optionalMap(String key) {
    if (!_map.containsKey(key)) return null;
    final value = _take(key);
    if (value is! Map<String, Object?>) fail(key, 'must be a JSON object');
    return value;
  }

  /// An optional list of JSON objects; absent means empty.
  List<_JsonObject> objectList(String key) {
    if (!_map.containsKey(key)) return const [];
    final value = _take(key);
    if (value is! List<Object?>) fail(key, 'must be a list of objects');
    return [
      for (var i = 0; i < value.length; i++)
        switch (value[i]) {
          final Map<String, Object?> element => _JsonObject(
            element,
            _context,
            '${_keyPath(key)}[$i]',
          ),
          _ => fail('$key[$i]', 'must be a JSON object'),
        },
    ];
  }

  /// The keys not read so far.
  Map<String, Object?> rest() => {
    for (final MapEntry(:key, :value) in _map.entries)
      if (!_used.contains(key)) key: value,
  };
}
