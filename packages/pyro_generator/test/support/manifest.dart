import 'dart:convert';

import 'harness.dart';

/// The parsed Manifest of a [GeneratorRun], with lookups for tests.
extension ManifestLookups on GeneratorRun {
  /// The Manifest as JSON.
  Map<String, Object?> get manifestJson =>
      jsonDecode(manifest!) as Map<String, Object?>;

  /// The type with Type ID [id], or null.
  Map<String, Object?>? type(String id) {
    for (final type in manifestJson['types']! as List<Object?>) {
      final map = type! as Map<String, Object?>;
      if (map['id'] == id) return map;
    }
    return null;
  }

  /// The fields of the type [id], by name, in Manifest order.
  Map<String, Map<String, Object?>> fields(String id) => {
    for (final field in type(id)!['fields']! as List<Object?>)
      (field! as Map<String, Object?>)['name']! as String:
          field as Map<String, Object?>,
  };

  /// The codes of every error and warning, in Manifest order.
  List<String> get codes => [
    for (final key in ['errors', 'warnings'])
      for (final d in manifestJson[key]! as List<Object?>)
        (d! as Map<String, Object?>)['code']! as String,
  ];
}

/// A library declaring `@PyroComponent class Host` with [members] in its
/// body, importing Flame, the annotations and [imports].
String hostLibrary(String members, {String imports = ''}) =>
    '''
import 'package:flame/components.dart';
import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:pyro_annotations/pyro_annotations.dart';
$imports
enum Mode { a, b }

enum Empty {}

@PyroComponent()
class Host extends PositionComponent {
$members
}
''';
