import 'dart:io';

import 'package:build_config/build_config.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

/// build.yaml: both builders auto-apply, and triggers keep unannotated
/// libraries cheap (FR-027, FR-028; research R2).
void main() {
  final config = BuildConfig.parse(
    'pyro_generator',
    const [],
    File.fromUri(
      packageLib('pyro_generator').uri.resolve('../build.yaml'),
    ).readAsStringSync(),
  );

  test('the scan writes to the cache and runs only when triggered', () {
    final scan = config.builderDefinitions['pyro_generator:pyro_scan']!;
    expect(scan.autoApply, AutoApply.dependents);
    expect(scan.buildTo, BuildTo.cache);
    expect(scan.buildExtensions, {
      '.dart': ['.pyro.json'],
    });
    expect(scan.runsBefore, ['pyro_generator:pyro_aggregate']);
    expect(scan.defaults.options['run_only_if_triggered'], isTrue);
  });

  test('the aggregate writes the two files into lib/', () {
    final aggregate =
        config.builderDefinitions['pyro_generator:pyro_aggregate']!;
    expect(aggregate.autoApply, AutoApply.dependents);
    expect(aggregate.buildTo, BuildTo.source);
    expect(aggregate.buildExtensions, {
      r'$lib$': ['pyro.g.dart', 'pyro.manifest.json'],
    });
    expect(aggregate.requiredInputs, ['.pyro.json']);
  });

  test('the scan is triggered by each of the three annotations', () {
    expect(config.triggersByBuilder['pyro_generator:pyro_scan'], [
      'annotation PyroBehavior',
      'annotation PyroComponent',
      'annotation Editable',
    ]);
  });

  test('a library with no Pyro annotation writes no fragment', () async {
    final run = await runGenerator({
      'lib/plain.dart': 'class Plain {}\n',
      'lib/good.dart': '''
import 'package:flame/components.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

@PyroComponent()
class Good extends PositionComponent {}
''',
    });
    expect(run.fragments.keys, ['lib/good.pyro.json']);
  });
}
