import 'package:test/test.dart';

import 'support/harness.dart';
import 'support/manifest.dart';

/// How the Registry names field types (FR-025, research R10).
void main() {
  test('imports field types through the libraries the class imports', () async {
    final run = await runGenerator({
      'lib/host.dart': '''
import 'package:flame/components.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

enum Mode { a, b }

@PyroComponent()
class Host extends PositionComponent {
  @Editable()
  Vector2 v = Vector2(0, 0);

  @Editable()
  Sprite? s;

  @Editable()
  Mode m = Mode.a;

  @Editable()
  ImagePath i = const ImagePath('a.png');
}
''',
    });
    final registry = run.registry!;
    expect(registry, contains("import 'package:flame/components.dart' as"));
    expect(registry, isNot(contains('/src/')));
    expect(registry, isNot(contains('vector_math')));
    expect(
      registry,
      contains("import 'package:pyro_annotations/pyro_annotations.dart' as"),
    );
    expect(registry, contains("import 'package:game/host.dart' as"));
  });

  test('same-named types in two libraries get their own prefixes', () async {
    final run = await runGenerator({
      'lib/a/player.dart': '''
import 'package:flame/components.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

@PyroComponent(id: 'a.player')
class Player extends PositionComponent {}
''',
      'lib/b/player.dart': '''
import 'package:flame/components.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

import '../a/player.dart' as a;

@PyroComponent(id: 'b.player')
class Player extends PositionComponent {
  @Editable()
  a.Player? buddy;
}
''',
    });
    final registry = run.registry!;
    final aPrefix = RegExp(
      r"import 'package:game/a/player\.dart' as (i\d+);",
    ).firstMatch(registry)!.group(1);
    final bPrefix = RegExp(
      r"import 'package:game/b/player\.dart' as (i\d+);",
    ).firstMatch(registry)!.group(1);
    expect(aPrefix, isNot(bPrefix));
    expect(registry, contains('create: $aPrefix.Player.new'));
    expect(registry, contains('create: $bPrefix.Player.new'));
    expect(registry, contains('v == null || v is $aPrefix.Player'));
  });

  test('imports and prefixes are sorted by URI', () async {
    final run = await runGenerator({
      'lib/z.dart': '''
import 'package:flame/components.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

@PyroComponent()
class Z extends PositionComponent {}
''',
      'lib/a.dart': '''
import 'package:flame/components.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

@PyroComponent()
class A extends PositionComponent {}
''',
    });
    final imports = RegExp(r"import '([^']+)' as (i\d+);")
        .allMatches(run.registry!)
        .map((m) => '${m.group(2)} ${m.group(1)}')
        .toList();
    expect(imports, [
      'i0 package:game/a.dart',
      'i1 package:game/z.dart',
      'i2 package:pyro_runtime/pyro_runtime.dart',
    ]);
  });

  test(
    "an inherited field's type is found through its declaring library",
    () async {
      final run = await runGenerator({
        'lib/base.dart': '''
import 'package:flame/components.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

class Base extends PositionComponent {
  @Editable()
  Vector2 v = Vector2(0, 0);
}
''',
        'lib/host.dart': '''
import 'package:pyro_annotations/pyro_annotations.dart';

import 'base.dart';

@PyroComponent()
class Host extends Base {}
''',
      });
      expect(run.manifestJson['errors'], isEmpty, reason: run.logText);
      expect(
        run.registry,
        contains("import 'package:flame/components.dart' as"),
      );
    },
  );
}
