import 'package:test/test.dart';

import 'support/harness.dart';
import 'support/manifest.dart';

/// Defaults from initializers (research R6).
void main() {
  Future<Map<String, Object?>> fieldOf(String declaration) async {
    final run = await runGenerator({
      'lib/host.dart': hostLibrary(
        '  @Editable()\n  $declaration',
        imports:
            "import 'package:pyro_annotations/pyro_annotations.dart' "
            'as p;\nconst kSpeed = 3.0;\n',
      ),
    });
    expect(run.codes, isEmpty, reason: run.logText);
    return (run.type('Host')!['fields']! as List<Object?>).single
        as Map<String, Object?>;
  }

  final evaluated = <String, Object?>{
    'int? x;': null,
    'int? x = null;': null,
    'int x = 50;': 50,
    'double x = 50;': 50,
    'double x = 50.0;': 50,
    'int x = -3;': -3,
    'double x = -0.5;': -0.5,
    'bool x = true;': true,
    "String x = 'text';": 'text',
    'Mode x = Mode.b;': 'b',
    'Mode x = .b;': 'b',
    "ImagePath x = const ImagePath('assets/images/a.png');": {
      'asset': 'assets/images/a.png',
    },
    "ImagePath x = ImagePath('assets/images/a.png');": {
      'asset': 'assets/images/a.png',
    },
    "ImagePath x = const p.ImagePath('a.png');": {'asset': 'a.png'},
  };
  for (final MapEntry(key: declaration, value: expected) in evaluated.entries) {
    test('$declaration has default ${expected ?? 'null'}', () async {
      final field = await fieldOf(declaration);
      expect(field['default'], expected);
      expect(field.containsKey('defaultSource'), isFalse);
    });
  }

  final sourceOnly = {
    'Vector2 x = Vector2(1, 0);': 'Vector2(1, 0)',
    "String x = 'a' 'b';": "'a' 'b'",
    "String x = '\${1}';": "'\${1}'",
    'double x = kSpeed;': 'kSpeed',
    'int x = 1 + 2;': '1 + 2',
  };
  for (final MapEntry(key: declaration, value: source) in sourceOnly.entries) {
    test('$declaration keeps its source text', () async {
      final field = await fieldOf(declaration);
      expect(field['default'], isNull);
      expect(field['defaultSource'], source);
    });
  }
}
