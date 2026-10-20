import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flame/components.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

import '../scene/overrides.dart';
import '../scene/values.dart';
import 'registry.dart';

/// What an Override's written value becomes for its field (research R5).
sealed class FieldConversion {
  const FieldConversion();
}

/// A value ready to assign.
final class ConvertedValue extends FieldConversion {
  /// Wraps [value].
  const ConvertedValue(this.value);

  /// The value to pass to the field's setter.
  final Object? value;
}

/// An asset the loader must load first: an image for a `Sprite` field, or
/// one [animation] of an animation file for a `SpriteAnimation` field.
final class AssetValue extends FieldConversion {
  /// Refers to the asset at [path].
  const AssetValue(this.path, {this.animation});

  /// The image or animation file.
  final AssetPath path;

  /// The animation's name, for a `SpriteAnimation` field.
  final String? animation;
}

/// A reference the loader resolves once every Node exists.
final class ReferenceValue extends FieldConversion {
  /// Refers to Node [target].
  const ReferenceValue(this.target);

  /// The referenced Node.
  final NodeId target;
}

/// A written value that doesn't fit its field.
final class Mismatch extends FieldConversion {
  /// Describes [written], which isn't [expected].
  const Mismatch(this.written, this.expected);

  /// The value in the file.
  final Object? written;

  /// What the field takes, such as `an int` or `"#AARRGGBB"`.
  final String expected;

  /// The message, naming the value and what was expected.
  String get message => written == null
      ? "the Override is null, but the field isn't nullable"
      : "the Override ${showValue(written)} isn't $expected";
}

/// The Override [written] converted for [field] (research R5): a value, an
/// asset or reference to resolve later, or a [Mismatch].
FieldConversion convertOverride(RegistryField field, Object? written) {
  if (written == null) {
    return field.nullable
        ? const ConvertedValue(null)
        : const Mismatch(null, 'a value');
  }
  Mismatch mismatch(String expected) => Mismatch(written, expected);
  switch (field.type) {
    case FieldType.int:
      if (written is int) return ConvertedValue(written);
      if (written is double &&
          written.isFinite &&
          written == written.truncateToDouble()) {
        return ConvertedValue(written.toInt());
      }
      return mismatch('an int');
    case FieldType.double:
      return written is num && written.isFinite
          ? ConvertedValue(written.toDouble())
          : mismatch('a number');
    case FieldType.bool:
      return written is bool
          ? ConvertedValue(written)
          : mismatch('true or false');
    case FieldType.string:
      return written is String ? ConvertedValue(written) : mismatch('a string');
    case FieldType.enumeration:
      final values = field.values ?? const <Enum>[];
      final names = values.map((v) => v.name).join(', ');
      if (written is! String) return mismatch('one of $names');
      for (final value in values) {
        if (value.name == written) return ConvertedValue(value);
      }
      return mismatch('one of $names');
    case FieldType.vector2:
      if (written case [
        final num x,
        final num y,
      ] when x.isFinite && y.isFinite) {
        return ConvertedValue(Vector2(x.toDouble(), y.toDouble()));
      }
      return mismatch('[x, y]');
    case FieldType.color:
      if (written is String && _color.hasMatch(written)) {
        return ConvertedValue(
          Color(int.parse(written.substring(1), radix: 16)),
        );
      }
      return mismatch('a colour "#AARRGGBB"');
    case FieldType.imagePath:
      final ref = AssetRef.fromJson(written);
      return ref != null && ref.animation == null
          ? ConvertedValue(ImagePath(ref.path))
          : mismatch('{"asset": path}');
    case FieldType.sprite:
      final ref = AssetRef.fromJson(written);
      return ref != null && ref.animation == null
          ? AssetValue(ref.path)
          : mismatch('{"asset": path}');
    case FieldType.spriteAnimation:
      final ref = AssetRef.fromJson(written);
      if (ref case AssetRef(:final path, animation: final String animation)) {
        return AssetValue(path, animation: animation);
      }
      return mismatch('{"asset": path, "animation": name}');
    case FieldType.entityRef:
      final ref = EntityRef.fromJson(written);
      return ref != null
          ? ReferenceValue(ref.target)
          : mismatch('{"ref": Node ID}');
  }
}

final RegExp _color = RegExp(r'^#[0-9A-Fa-f]{8}$');

/// [value] as it is written in the file, cut to 80 characters.
String showValue(Object? value) {
  final text = jsonEncode(value);
  return text.length <= 80 ? text : '${text.substring(0, 79)}…';
}
