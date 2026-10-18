import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

void main() {
  late List<String> printed;
  late DebugPrintCallback original;

  setUp(() {
    printed = [];
    original = debugPrint;
    debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
  });

  tearDown(() => debugPrint = original);

  test('prints one warning naming the Scene, each repair and the advice', () {
    final report = RepairReport([
      const MissingChild(parentId: NodeId('root'), childId: NodeId('ghost')),
      const OrphanAttached(nodeId: NodeId('e')),
    ]);
    warnAboutRepairs('assets/scenes/level1.scene.json', report);

    expect(printed, hasLength(1));
    final warning = printed.single;
    expect(warning, contains('assets/scenes/level1.scene.json'));
    expect(warning, contains(report.issues[0].description));
    expect(warning, contains(report.issues[1].description));
    expect(warning, contains('Open this Scene in Pyro and save it'));
  });

  test('prints nothing for a healthy Scene', () {
    warnAboutRepairs('assets/scenes/level1.scene.json', RepairReport.empty);
    expect(printed, isEmpty);
  });
}
