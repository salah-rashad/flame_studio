import 'dart:io';

import 'package:test/test.dart';

import 'support/harness.dart';

/// Outputs depend only on what a reader of them sees (spec US3, FR-029,
/// FR-030).
void main() {
  late Map<String, String> full;
  late GeneratorRun baseline;

  setUpAll(() async {
    final input = Directory('test/goldens/full/input');
    full = {
      for (final file in input.listSync(recursive: true).whereType<File>())
        file.path.substring(input.path.length + 1).replaceAll(r'\', '/'): file
            .readAsStringSync(),
    };
    baseline = await runGenerator(full);
  });

  Future<GeneratorRun> edited(String path, String from, String to) {
    final source = full[path]!;
    expect(source, contains(from), reason: 'the edit must apply to $path');
    return runGenerator({...full, path: source.replaceFirst(from, to)});
  }

  test('the order sources arrive in changes nothing (US3 #3)', () async {
    final reversed = Map.fromEntries(full.entries.toList().reversed);
    final run = await runGenerator(reversed);
    expect(run.registry, baseline.registry);
    expect(run.manifest, baseline.manifest);
  });

  test('reordering classes within a file changes nothing (US3 #3)', () async {
    final run = await runGenerator({
      ...full,
      'lib/components/enemy.dart': '''
import 'package:flame/components.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

@PyroComponent(id: 'enemy.base', label: 'Enemy', category: 'Enemies')
class Enemy extends Hurtable with Glows {
  @Editable()
  double health2 = 2.5;
}

mixin Glows on PositionComponent {
  @Editable()
  double glow = 0.5;
}

abstract class Hurtable extends PositionComponent {
  @Editable()
  int health = 10;
}
''',
    });
    expect(run.registry, baseline.registry);
    expect(run.manifest, baseline.manifest);
  });

  test('a method body edit changes nothing (US3 #4)', () async {
    final run = await edited(
      'lib/behaviors/patrol.dart',
      '  int steps = 0;',
      '  int steps = 0;\n\n  void walk() => steps++;',
    );
    expect(run.registry, baseline.registry);
    expect(run.manifest, baseline.manifest);
  });

  test('an unannotated file changes nothing (US3 #4)', () async {
    final run = await runGenerator({
      ...full,
      'lib/util.dart': 'int twice(int x) => x * 2;\n',
    });
    expect(run.registry, baseline.registry);
    expect(run.manifest, baseline.manifest);
  });

  final displayOnly = {
    'tooltip': (
      'lib/behaviors/patrol.dart',
      "tooltip: 'Pixels per second'",
      "tooltip: 'Pixels each second'",
    ),
    'label': ('lib/behaviors/patrol.dart', "label: 'Patrol'", "label: 'Walk'"),
    'category': (
      'lib/behaviors/patrol.dart',
      "category: 'Movement'",
      "category: 'Moves'",
    ),
    'doc comment': (
      'lib/behaviors/patrol.dart',
      '/// Walks between two points.',
      '/// Walks back and forth.',
    ),
  };
  for (final MapEntry(key: what, value: (path, from, to))
      in displayOnly.entries) {
    test('a $what edit changes only the Manifest (US3 #5)', () async {
      final run = await edited(path, from, to);
      expect(run.registry, baseline.registry);
      expect(run.manifest, isNot(baseline.manifest));
    });
  }

  test('removing the last annotation from a library removes its type and '
      'fragment', () async {
    expect(baseline.fragments.keys, contains('lib/behaviors/blink.pyro.json'));
    final run = await runGenerator({
      ...full,
      'lib/behaviors/blink.dart': 'class Blink {}\n',
    });
    expect(
      run.fragments.keys,
      isNot(contains('lib/behaviors/blink.pyro.json')),
    );
    expect(run.registry, isNot(contains("TypeId('Blink')")));
    expect(run.manifest, isNot(contains('"Blink"')));
  });

  test('outputs hold no run-dependent content (US3 #2)', () {
    for (final text in [baseline.registry!, baseline.manifest!]) {
      expect(text, isNot(contains('\r')));
      expect(text, isNot(contains(Directory.current.path)));
      expect(text, isNot(contains(Directory.systemTemp.path)));
      expect(text, isNot(matches(RegExp(r'20\d\d-\d\d-\d\d'))));
    }
  });
}
