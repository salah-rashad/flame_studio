/// Writes [value] in the canonical form of the Scene file contract
/// (research R2, R3):
///
/// - LF line endings, two-space indentation, one trailing newline;
/// - top-level keys in [topLevelOrder] first, then every other object key
///   sorted by `String.compareTo`;
/// - `{}` and `[]` for empty collections, one member or element per line
///   otherwise, except arrays of numbers, which stay on one line;
/// - one written form per number on every platform;
/// - strings escaping only `"`, `\` and control characters.
///
/// Throws [UnwritableJsonValue] for NaN, infinities and values that aren't
/// JSON values.
String writeCanonicalJson(
  Object? value, {
  List<String> topLevelOrder = const [],
}) {
  final writer = _CanonicalWriter(topLevelOrder);
  writer.write(value, 0);
  writer.out.write('\n');
  return writer.out.toString();
}

/// A value [writeCanonicalJson] can't write, at [path] (keys and indices
/// from the top level).
final class UnwritableJsonValue implements Exception {
  /// Creates the error for [value] at [path].
  const UnwritableJsonValue(this.value, this.path);

  /// The value.
  final Object? value;

  /// Keys (`String`) and indices (`int`) from the top level to the value.
  final List<Object> path;

  @override
  String toString() => 'UnwritableJsonValue($value at ${path.join('/')})';
}

final class _CanonicalWriter {
  _CanonicalWriter(this.topLevelOrder);

  final List<String> topLevelOrder;
  final StringBuffer out = StringBuffer();
  final List<Object> _path = [];

  void write(Object? value, int indent) {
    switch (value) {
      case null:
        out.write('null');
      case bool():
        out.write(value ? 'true' : 'false');
      case num():
        out.write(_number(value));
      case String():
        _string(value);
      case Map<String, Object?>():
        _object(value, indent);
      case List<Object?>():
        _array(value, indent);
      default:
        throw UnwritableJsonValue(value, List.of(_path));
    }
  }

  void _object(Map<String, Object?> map, int indent) {
    if (map.isEmpty) {
      out.write('{}');
      return;
    }
    final keys = <String>[];
    if (indent == 0 && topLevelOrder.isNotEmpty) {
      keys.addAll(topLevelOrder.where(map.containsKey));
      keys.addAll(
        map.keys.where((k) => !topLevelOrder.contains(k)).toList()..sort(),
      );
    } else {
      keys.addAll(map.keys.toList()..sort());
    }
    final inner = indent + 2;
    out.write('{\n');
    for (var i = 0; i < keys.length; i++) {
      final key = keys[i];
      _indent(inner);
      _string(key);
      out.write(': ');
      _path.add(key);
      write(map[key], inner);
      _path.removeLast();
      if (i < keys.length - 1) out.write(',');
      out.write('\n');
    }
    _indent(indent);
    out.write('}');
  }

  void _array(List<Object?> list, int indent) {
    if (list.isEmpty) {
      out.write('[]');
      return;
    }
    if (list.every((e) => e is num)) {
      out.write('[');
      for (var i = 0; i < list.length; i++) {
        if (i > 0) out.write(', ');
        _path.add(i);
        out.write(_number(list[i]! as num));
        _path.removeLast();
      }
      out.write(']');
      return;
    }
    final inner = indent + 2;
    out.write('[\n');
    for (var i = 0; i < list.length; i++) {
      _indent(inner);
      _path.add(i);
      write(list[i], inner);
      _path.removeLast();
      if (i < list.length - 1) out.write(',');
      out.write('\n');
    }
    _indent(indent);
    out.write(']');
  }

  void _indent(int spaces) {
    for (var i = 0; i < spaces; i++) {
      out.write(' ');
    }
  }

  /// One written form per number on the VM and on the web (research R3).
  String _number(num value) {
    if (value is int) return value.toString();
    final d = value.toDouble();
    if (!d.isFinite) throw UnwritableJsonValue(value, List.of(_path));
    if (d == d.truncateToDouble() && d.abs() < 1e21) {
      // Digits only, never `80.0`; -0.0 becomes 0.
      return d.abs() < 9e15 ? d.toInt().toString() : BigInt.from(d).toString();
    }
    return d.toString();
  }

  void _string(String s) {
    out.writeCharCode(0x22);
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      switch (c) {
        case 0x22:
          out.write(r'\"');
        case 0x5C:
          out.write(r'\\');
        case 0x08:
          out.write(r'\b');
        case 0x0C:
          out.write(r'\f');
        case 0x0A:
          out.write(r'\n');
        case 0x0D:
          out.write(r'\r');
        case 0x09:
          out.write(r'\t');
        default:
          if (c < 0x20) {
            out.write(r'\u00');
            out.write(c.toRadixString(16).padLeft(2, '0'));
          } else {
            out.writeCharCode(c);
          }
      }
    }
    out.writeCharCode(0x22);
  }
}
