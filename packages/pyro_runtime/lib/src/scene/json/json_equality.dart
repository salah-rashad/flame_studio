/// Deep equality for JSON values (`null`, `bool`, `num`, `String`, lists and
/// string-keyed maps), used by value types that carry unknown keys.
bool jsonEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List<Object?> && b is List<Object?>) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!jsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map<String, Object?> && b is Map<String, Object?>) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || !jsonEquals(entry.value, b[entry.key])) {
        return false;
      }
    }
    return true;
  }
  return a == b;
}

/// A hash code consistent with [jsonEquals]; map key order doesn't matter.
int jsonHash(Object? value) => switch (value) {
  List<Object?>() => Object.hashAll(value.map(jsonHash)),
  Map<String, Object?>() => Object.hashAllUnordered(
    value.entries.map((e) => Object.hash(e.key, jsonHash(e.value))),
  ),
  _ => value.hashCode,
};
