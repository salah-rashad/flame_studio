import 'package:test/test.dart';

import 'support/harness.dart';
import 'support/manifest.dart';

/// Inherited and mixin fields (FR-013).
void main() {
  test('lists superclass and mixin fields top-down, then the class', () async {
    final run = await runGenerator({
      'lib/base.dart': '''
import 'package:flame/components.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

mixin Glows on PositionComponent {
  @Editable()
  double glow = 0.5;
}

class Base extends PositionComponent with Glows {
  @Editable()
  int a = 1;
}
''',
      'lib/host.dart': '''
import 'package:pyro_annotations/pyro_annotations.dart';

import 'base.dart';

mixin Ticks on Base {
  @Editable()
  int ticks = 0;
}

@PyroComponent()
class Host extends Base with Ticks {
  @Editable()
  int b = 2;
}
''',
    });
    expect(run.codes, isEmpty, reason: run.logText);
    final fields = run.fields('Host');
    expect(fields.keys, ['glow', 'a', 'ticks', 'b']);
    expect(fields['glow']!['declaredIn'], 'Glows');
    expect(fields['a']!['declaredIn'], 'Base');
    expect(fields['ticks']!['declaredIn'], 'Ticks');
    expect(fields['b']!.containsKey('declaredIn'), isFalse);
  });

  test('a redeclared field keeps its first position and the lower '
      'declaration', () async {
    final run = await runGenerator({
      'lib/host.dart': '''
import 'package:flame/components.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

@PyroComponent(id: 'base')
class Base extends PositionComponent {
  @Editable()
  int a = 1;

  @Editable()
  int b = 2;
}

@PyroComponent()
class Host extends Base {
  @Editable(tooltip: 'mine')
  @override
  int a = 10;
}
''',
    });
    expect(run.codes, isEmpty, reason: run.logText);
    final fields = run.fields('Host');
    expect(fields.keys, ['a', 'b']);
    expect(fields['a']!['default'], 10);
    expect(fields['a']!['tooltip'], 'mine');
    expect(fields['a']!.containsKey('declaredIn'), isFalse);
    expect(fields['b']!['declaredIn'], 'Base');
    expect(run.type('Host')!['supertypes'], [
      'base',
      'PositionComponent',
      'Component',
    ]);
  });

  test('a mixin used by an annotated class is not an unused holder', () async {
    final run = await runGenerator({
      'lib/host.dart': hostLibrary('').replaceFirst(
        'class Host extends PositionComponent',
        'mixin M on PositionComponent {\n  @Editable()\n  int m = 1;\n}\n\n'
            '@PyroComponent()\nclass Other extends PositionComponent with M {}'
            '\n\nclass Host2 extends PositionComponent',
      ),
    });
    expect(run.codes, isEmpty, reason: run.logText);
    expect(run.fields('Other').keys, ['m']);
  });
}
