import 'values.dart';

/// The Overrides of one Behavior or Custom component: the Editable field
/// values the developer explicitly set, by field name (ADR 0003).
///
/// A field without an Override takes its default from code, so it is absent
/// here. An Override equal to the code default is still an Override.
/// Values are JSON values in the written forms of the Scene file contract;
/// this class doesn't interpret them, and keeps values for fields no code
/// knows (FR-011).
final class Overrides {
  /// Creates Overrides from [values], a map of field name to JSON value.
  Overrides(Map<String, Object?> values) : values = Map.unmodifiable(values);

  /// No Overrides.
  const Overrides.empty() : values = const {};

  /// The Override values by field name.
  final Map<String, Object?> values;

  /// Whether there are no Overrides.
  bool get isEmpty => values.isEmpty;

  /// The Override for [field], or null if there is none.
  Object? operator [](String field) => values[field];

  /// Whether [field] has an Override.
  bool contains(String field) => values.containsKey(field);

  /// A copy with [field] overridden to [value].
  Overrides put(String field, Object? value) =>
      Overrides({...values, field: value});

  /// A copy without the Override for [field] (*Reset to default*).
  Overrides reset(String field) => Overrides({...values}..remove(field));

  @override
  String toString() => 'Overrides($values)';
}

/// A Behavior attached to an entity or Custom component Node: its Type ID
/// and its Overrides.
final class BehaviorAttachment {
  /// Creates the attachment of Behavior [type].
  BehaviorAttachment({
    required this.type,
    this.fields = const Overrides.empty(),
    Map<String, Object?> extra = const {},
  }) : extra = Map.unmodifiable(extra);

  /// The Behavior's Type ID.
  final TypeId type;

  /// The Behavior's Overrides.
  final Overrides fields;

  /// Unknown keys of the Behavior object, kept and written back (FR-017).
  final Map<String, Object?> extra;

  /// A copy with the given fields replaced.
  BehaviorAttachment copyWith({
    TypeId? type,
    Overrides? fields,
    Map<String, Object?>? extra,
  }) => BehaviorAttachment(
    type: type ?? this.type,
    fields: fields ?? this.fields,
    extra: extra ?? this.extra,
  );

  @override
  String toString() => 'BehaviorAttachment($type, $fields)';
}

/// An entity reference Override value: `{"ref": "<Node ID>"}`, pointing at
/// another Node of the same Scene.
///
/// A reference to a Node that doesn't exist is kept as written; resolving it
/// is the loader's and the inspector's job.
final class EntityRef {
  /// Creates a reference to Node [target].
  const EntityRef(this.target);

  /// The referenced Node.
  final NodeId target;

  /// The reference in [value], or null if [value] isn't exactly
  /// `{"ref": "<non-empty string>"}`.
  static EntityRef? fromJson(Object? value) {
    final target = _singleString(value, 'ref');
    return target == null ? null : EntityRef(NodeId(target));
  }

  /// The written form, `{"ref": "<Node ID>"}`.
  Map<String, Object?> toJson() => {'ref': target};

  @override
  bool operator ==(Object other) =>
      other is EntityRef && other.target == target;

  @override
  int get hashCode => target.hashCode;

  @override
  String toString() => 'EntityRef($target)';
}

/// An asset reference Override value: `{"asset": "<asset path>"}`.
///
/// Tagged, unlike a plain string, so Pyro can find and rewrite asset paths
/// in any Scene without the Manifest, including inside Missing behaviors
/// (research R6).
final class AssetRef {
  /// Creates a reference to the asset at [path].
  const AssetRef(this.path);

  /// The asset's path.
  final AssetPath path;

  /// The reference in [value], or null if [value] isn't exactly
  /// `{"asset": "<non-empty string>"}`.
  static AssetRef? fromJson(Object? value) {
    final path = _singleString(value, 'asset');
    return path == null ? null : AssetRef(AssetPath(path));
  }

  /// The written form, `{"asset": "<asset path>"}`.
  Map<String, Object?> toJson() => {'asset': path};

  @override
  bool operator ==(Object other) => other is AssetRef && other.path == path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'AssetRef($path)';
}

/// The string in [value] if it is a map holding only [key] with a non-empty
/// string.
String? _singleString(Object? value, String key) {
  if (value is! Map<String, Object?> || value.length != 1) return null;
  final string = value[key];
  return string is String && string.isNotEmpty ? string : null;
}
