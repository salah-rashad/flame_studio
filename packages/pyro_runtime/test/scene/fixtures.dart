import 'dart:convert';
import 'dart:io';

const String _root = 'test/fixtures/scenes';

/// Reads `test/fixtures/scenes/<relativePath>` exactly as stored: line
/// endings and a byte-order mark are kept, so round-trip tests compare real
/// bytes.
String readFixture(String relativePath) =>
    utf8.decode(File('$_root/$relativePath').readAsBytesSync());

/// The fixture names in [folder] ending in [suffix], sorted, without the
/// `*.expected.scene.json` files that hold expected outputs.
List<String> fixtureNames(String folder, {String suffix = '.scene.json'}) {
  final names = <String>[
    for (final entity in Directory('$_root/$folder').listSync())
      if (entity is File &&
          entity.path.endsWith(suffix) &&
          !entity.path.endsWith('.expected.scene.json'))
        entity.uri.pathSegments.last,
  ]..sort();
  return names;
}

/// The expected-output fixture for `<folder>/<name>.scene.json`.
String readExpected(String folder, String name) => readFixture(
  '$folder/${name.replaceFirst('.scene.json', '.expected.scene.json')}',
);
