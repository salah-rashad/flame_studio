// Generates a synthetic mid-size game project that uses the spike generator.
//
//   dart run bin/gen_project.dart --out ../sample --files 300 --annotated 40
//
// Layout (all under lib/):
//   core/core_NNN.dart       unannotated chain; every annotated file imports
//                            core_000 transitively (worst case for edits)
//   util/util_NNN.dart       unannotated leaves, imported by nobody
//   systems/system_NNN.dart  unannotated, import a few core files + flame
//   behaviors/behavior_NNN.dart    @StudioBehavior
//   components/component_NNN.dart  @StudioComponent
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) {
  final parser = ArgParser()
    ..addOption('out', defaultsTo: '../sample')
    ..addOption('files', defaultsTo: '300', help: 'Total Dart files in lib/')
    ..addOption('annotated', defaultsTo: '40')
    ..addOption(
      'flavor',
      allowed: ['flutter', 'dart'],
      defaultsTo: 'flutter',
      help: 'flutter: real Flame (Flutter SDK pins build_runner). '
          'dart: pure Dart with Flame-shaped stubs (newest build_runner).',
    )
    ..addFlag(
      'triggers',
      defaultsTo: true,
      help: 'run_only_if_triggered for the scanner (off = scan every file)',
    );
  final o = parser.parse(args);
  final out = p.normalize(p.absolute(o['out'] as String));
  final total = int.parse(o['files'] as String);
  final annotated = int.parse(o['annotated'] as String);
  final flutter = o['flavor'] == 'flutter';

  final rest = total - annotated;
  final core = (rest * 0.3).round();
  final util = (rest * 0.3).round();
  final systems = rest - core - util;
  final components = (annotated * 0.25).round().clamp(1, annotated);
  final behaviors = annotated - components;

  final lib = Directory(p.join(out, 'lib'));
  if (lib.existsSync()) lib.deleteSync(recursive: true);
  lib.createSync(recursive: true);

  final here = p.dirname(p.dirname(Platform.script.toFilePath()));
  final spike = p.dirname(here);
  String rel(String sub) =>
      p.relative(p.join(spike, sub), from: out).replaceAll(r'\', '/');

  File(p.join(out, 'pubspec.yaml')).writeAsStringSync('''
name: sample_game
description: "Spike #2 synthetic mid-size project (generated)."
publish_to: 'none'
version: 0.0.1

environment:
  sdk: ^3.12.0

dependencies:
${flutter ? '''  flame: ^1.38.2
  flame_behaviors: ^1.4.0
  flutter:
    sdk: flutter
''' : ''}  studio_annotations:
    path: ${rel('studio_annotations')}

dev_dependencies:
  build_runner: ${flutter ? '">=2.14.0 <3.0.0"' : '^2.17.1'}
  studio_generator:
    path: ${rel('studio_generator')}
''');

  File(p.join(out, 'build.yaml')).writeAsStringSync('''
targets:
  \$default:
    builders:
      studio_generator:studio_scan:
        options:
          run_only_if_triggered: ${o['triggers']}
''');

  File(p.join(out, '.gitignore')).writeAsStringSync('*\n');

  final flameImports = flutter
      ? "import 'package:flame/components.dart';\n"
          "import 'package:flame_behaviors/flame_behaviors.dart';\n"
      : "import 'package:sample_game/flame_stub.dart';\n";
  if (!flutter) _writeStub(lib.path);

  // core: a chain, core_i imports core_{i-1} and core_{i/2}.
  for (var i = 0; i < core; i++) {
    final imports = {
      if (i > 0) i - 1,
      if (i > 1) i ~/ 2,
    }.map((j) => "import 'core_${_n(j)}.dart';").join('\n');
    _write(lib.path, 'core/core_${_n(i)}.dart', '''
$flameImports$imports

${_body('Core${_n(i)}', i)}
''');
  }
  for (var i = 0; i < util; i++) {
    _write(lib.path, 'util/util_${_n(i)}.dart', _body('Util${_n(i)}', i));
  }
  for (var i = 0; i < systems; i++) {
    final a = (i * 7) % core, b = (i * 13 + 5) % core;
    _write(lib.path, 'systems/system_${_n(i)}.dart', '''
$flameImports
import '../core/core_${_n(a)}.dart';
import '../core/core_${_n(b)}.dart';

${_body('System${_n(i)}', i)}
''');
  }
  for (var i = 0; i < components; i++) {
    _write(lib.path, 'components/component_${_n(i)}.dart', '''
$flameImports
import 'package:studio_annotations/studio_annotations.dart';

import '../core/core_${_n(core - 1 - (i % 5))}.dart';

/// Synthetic component $i.
@StudioComponent(category: 'Group ${i % 4}')
class Component${_n(i)} extends PositionedEntity {
  @Editable(min: 0, max: 10)
  int lives = $i;

  @Editable(tooltip: 'Name $i')
  String nickname = 'c$i';

  @Editable()
  bool active = true;

  ${_methods('Component${_n(i)}', i)}
}
''');
  }
  for (var i = 0; i < behaviors; i++) {
    final target = 'Component${_n(i % components)}';
    _write(lib.path, 'behaviors/behavior_${_n(i)}.dart', '''
$flameImports
import 'package:studio_annotations/studio_annotations.dart';

import '../components/component_${_n(i % components)}.dart';
import '../core/core_${_n(core - 1 - (i % 7))}.dart';

enum Mode${_n(i)} { a, b, c }

/// Synthetic behavior $i.
@StudioBehavior(category: 'Group ${i % 6}')
class Behavior${_n(i)} extends Behavior<PositionedEntity> {
  @Editable(min: 0, max: 400, tooltip: 'Speed $i')
  double speed = ${i + 1}.0;

  @Editable()
  Vector2 direction = Vector2(1, 0);

  @Editable()
  Mode${_n(i)} mode = Mode${_n(i)}.a;

  @Editable()
  $target? target;

  ${_methods('Behavior${_n(i)}', i)}

  @override
  void update(double dt) {
    parent.position.add(direction * speed * dt);
  }
}
''');
  }
  _write(lib.path, 'game.dart', '''
${flutter ? "import 'package:flame/game.dart';" : "import 'flame_stub.dart';"}

class SampleGame extends FlameGame {}
''');

  stdout.writeln('Wrote $out: $total+ files in lib/ '
      '(core $core, util $util, systems $systems, '
      'behaviors $behaviors, components $components; '
      'flavor ${o['flavor']}, triggers ${o['triggers']})');
}

String _n(int i) => i.toString().padLeft(3, '0');

void _write(String lib, String rel, String content) {
  final f = File(p.join(lib, rel));
  f.parent.createSync(recursive: true);
  f.writeAsStringSync(content);
}

/// Roughly 60 lines of ordinary code, so files cost something to analyze.
String _body(String name, int seed) => '''
/// Synthetic class $name.
class $name {
  final List<double> values = List.generate(${seed % 9 + 3}, (i) => i * 1.5);
  final Map<String, int> counters = {};
  int ticks = 0;

  ${_methods(name, seed)}
}

enum ${name}State { idle, running, done }

$name make$name() => $name();
''';

String _methods(String name, int seed) => List.generate(6, (m) => '''
double compute$m(double x) {
    var acc = x;
    for (var i = 0; i < ${m + 3}; i++) {
      acc = acc * ${seed % 5 + 1} + i - ${m * 2};
      if (acc > 1000) acc /= ${m + 2};
    }
    return acc;
  }
''').join('\n  ');

void _writeStub(String lib) {
  _write(lib, 'flame_stub.dart', '''
/// Flame-shaped stubs for the pure-Dart flavor.
class Vector2 {
  double x, y;
  Vector2(this.x, this.y);
  Vector2 operator *(double s) => Vector2(x * s, y * s);
  void add(Vector2 o) { x += o.x; y += o.y; }
}
class Color { final int value; const Color(this.value); }
class Sprite {}
class SpriteAnimation {}
class Component { void update(double dt) {} }
class PositionComponent extends Component { Vector2 position = Vector2(0, 0); }
mixin EntityMixin on Component {}
class PositionedEntity extends PositionComponent with EntityMixin {}
abstract class Behavior<T extends PositionedEntity> extends Component {
  late T parent;
}
class FlameGame extends Component {}
''');
}
