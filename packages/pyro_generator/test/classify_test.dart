import 'package:test/test.dart';

import 'support/harness.dart';
import 'support/manifest.dart';

/// Field type classification (research R5, FR-011).
void main() {
  Future<Map<String, Object?>?> fieldOf(String declaration) async {
    final run = await runGenerator({
      'lib/host.dart': hostLibrary(
        '  @Editable()\n  $declaration',
        imports:
            "import 'package:vector_math/vector_math_64.dart' as v64;\n"
            'typedef Speed = double;\n',
      ),
    });
    final host = run.type('Host');
    if (host == null) return null;
    return (host['fields']! as List<Object?>).single as Map<String, Object?>;
  }

  final supported = {
    'int x = 1;': ('int', false),
    'double x = 1;': ('double', false),
    'bool x = true;': ('bool', false),
    'String x = "";': ('string', false),
    'Mode x = Mode.a;': ('enum', false),
    'Vector2 x = Vector2(0, 0);': ('vector2', false),
    'ImagePath x = const ImagePath("a.png");': ('imagePath', false),
    'Sprite? x;': ('sprite', true),
    'SpriteAnimation? x;': ('spriteAnimation', true),
    'Component? x;': ('entityRef', true),
    'PositionComponent? x;': ('entityRef', true),
    'PositionedEntity? x;': ('entityRef', true),
    'int? x;': ('int', true),
    'Speed x = 1;': ('double', false),
  };
  for (final MapEntry(key: declaration, value: (type, nullable))
      in supported.entries) {
    test('$declaration is a $type field', () async {
      final field = await fieldOf(declaration);
      expect(field, isNotNull, reason: 'Host was left out');
      expect(field!['type'], type);
      expect(field['nullable'], nullable);
    });
  }

  final unsupported = [
    'num x = 1;',
    'dynamic x;',
    'Object x = 1;',
    'List<int> x = [];',
    'Map<String, int> x = {};',
    '(int, int) x = (1, 2);',
    'void Function() x = _f;',
    'v64.Vector2 x = v64.Vector2(0, 0);',
    'Behavior? x;',
    'Empty? x;',
  ];
  for (final declaration in unsupported) {
    test('$declaration is not a Field type', () async {
      final run = await runGenerator({
        'lib/host.dart': hostLibrary(
          '  @Editable()\n  $declaration',
          imports:
              "import 'package:vector_math/vector_math_64.dart' as v64;\n"
              'void _f() {}\n',
        ),
      });
      expect(run.type('Host'), isNull);
      expect(run.codes, ['unsupportedFieldType']);
    });
  }
}
