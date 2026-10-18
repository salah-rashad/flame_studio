import 'dart:io';
import 'dart:typed_data';

/// The Runtime's Scene fixtures, read in place so the format has one set of
/// fixtures (spec 002, research R15). `flutter test` runs with the package
/// root as the working directory.
const String fixturesRoot = '../../packages/pyro_runtime/test/fixtures/scenes';

/// The raw bytes of `fixtures/<relative>`, with line endings untouched.
Uint8List readFixtureBytes(String relative) {
  final file = File('$fixturesRoot/$relative');
  if (!file.existsSync()) {
    throw StateError('Fixture not found: ${file.absolute.path}');
  }
  return file.readAsBytesSync();
}

/// The `*.scene.json` files in `fixtures/<folder>`, without the
/// `*.expected.scene.json` ones, sorted.
List<String> fixtureNames(String folder) {
  final dir = Directory('$fixturesRoot/$folder');
  if (!dir.existsSync()) {
    throw StateError('Fixture folder not found: ${dir.absolute.path}');
  }
  final names =
      [
            for (final entity in dir.listSync())
              if (entity is File) entity.uri.pathSegments.last,
          ]
          .where((name) => name.endsWith('.scene.json'))
          .where((name) => !name.endsWith('.expected.scene.json'));
  return names.toList()..sort();
}
