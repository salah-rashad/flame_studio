import 'dart:convert';

/// Writes [value] as canonical JSON: keys sorted at every level, two-space
/// indentation, LF line endings and a trailing newline (research R7).
///
/// Numbers follow the Scene format's rule (*Q92*): a `double` with no
/// fractional part is written as an integer, any other number in Dart's
/// shortest round-trip form. Supports maps with string keys, lists, strings,
/// numbers, booleans and null, whatever their type arguments.
String canonicalJson(Object? value) {
  final out = StringBuffer();
  _write(out, value, '');
  out.write('\n');
  return out.toString();
}

void _write(StringBuffer out, Object? value, String indent) {
  switch (value) {
    case null || bool() || String():
      out.write(jsonEncode(value));
    case num():
      out.write(_number(value));
    case Map():
      if (value.isEmpty) {
        out.write('{}');
        return;
      }
      final inner = '$indent  ';
      final keys = [for (final key in value.keys) key as String]..sort();
      out.write('{\n');
      for (var i = 0; i < keys.length; i++) {
        out
          ..write(inner)
          ..write(jsonEncode(keys[i]))
          ..write(': ');
        _write(out, value[keys[i]], inner);
        out.write(i == keys.length - 1 ? '\n' : ',\n');
      }
      out
        ..write(indent)
        ..write('}');
    case List():
      if (value.isEmpty) {
        out.write('[]');
        return;
      }
      final inner = '$indent  ';
      out.write('[\n');
      for (var i = 0; i < value.length; i++) {
        out.write(inner);
        _write(out, value[i], inner);
        out.write(i == value.length - 1 ? '\n' : ',\n');
      }
      out
        ..write(indent)
        ..write(']');
    default:
      throw ArgumentError.value(value, 'value', 'Not a JSON value');
  }
}

String _number(num value) {
  if (value is double) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'value', 'JSON has no $value');
    }
    if (value == value.truncateToDouble() && value.abs() < 1e15) {
      return value.toInt().toString();
    }
  }
  return value.toString();
}
