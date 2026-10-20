import 'package:test/test.dart';

import 'support/harness.dart';
import 'support/manifest.dart';

const _header = '''
import 'package:flame/components.dart';
import 'package:pyro_annotations/pyro_annotations.dart';
''';

const _good =
    '''
$_header
@PyroComponent()
class Good extends PositionComponent {}
''';

const _broken =
    '''
$_header
@PyroComponent()
class Patrol extends PositionComponent {
  @Editable()
  Map<String, int> loot = {};
}
''';

const _fixed =
    '''
$_header
@PyroComponent()
class Patrol extends PositionComponent {
  @Editable()
  int loot = 0;
}
''';

/// Failing builds (spec US2 #7, #9; FR-020).
void main() {
  test('a failing build still writes both outputs, with the errors', () async {
    final run = await runGenerator({
      'lib/good.dart': _good,
      'lib/patrol.dart': _broken,
    });
    expect(run.succeeded, isFalse);
    expect(run.registry, isNotNull);
    expect(run.registry, contains("TypeId('Good')"));
    expect(run.registry, isNot(contains('Patrol')));
    expect(run.type('Good'), isNotNull);
    expect(run.type('Patrol'), isNull);
    expect(run.codes, ['unsupportedFieldType']);
  });

  test('building again without a fix reports the same errors', () async {
    final sources = {'lib/good.dart': _good, 'lib/patrol.dart': _broken};
    final first = await runGenerator(sources);
    final second = await runGenerator(sources);
    expect(second.succeeded, isFalse);
    expect(second.log, first.log);
    expect(second.manifest, first.manifest);
  });

  test('fixing the cause brings the type back and clears the errors', () async {
    final run = await runGenerator({
      'lib/good.dart': _good,
      'lib/patrol.dart': _fixed,
    });
    expect(run.succeeded, isTrue);
    expect(run.codes, isEmpty);
    expect(run.type('Patrol'), isNotNull);
    expect(run.registry, contains("TypeId('Patrol')"));
  });

  test('a warning alone does not fail the build', () async {
    final run = await runGenerator({
      'lib/good.dart':
          '''
$_header
@PyroComponent()
class Good extends PositionComponent {
  @Editable(min: 0, max: 1)
  double level = 2;
}
''',
    });
    expect(run.succeeded, isTrue);
    expect(run.codes, ['defaultOutOfRange']);
    expect(run.type('Good'), isNotNull);
  });
}
