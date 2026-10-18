import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../helpers.dart';

/// Records lock calls; [move] plays the native side's movement reports.
class _FakeLock implements PrPointerLock {
  _FakeLock({this.grant = true});

  final bool grant;
  final log = <String>[];
  void Function(Offset delta)? _onMove;

  void move(double dx) => _onMove?.call(Offset(dx, 0));

  @override
  Future<bool> lock(void Function(Offset delta) onMove) async {
    log.add('lock');
    _onMove = onMove;
    return grant;
  }

  @override
  Future<void> unlock() async {
    log.add('unlock');
    _onMove = null;
  }
}

void main() {
  late List<double> changes;
  late List<double> commits;

  setUp(() {
    changes = [];
    commits = [];
  });

  Widget number(PrPointerLock? lock) => PrPlatformHooks(
    pointerLock: lock,
    child: StatefulBuilder(
      builder: (context, setState) => PrNumberProperty(
        label: 'priority',
        value: changes.isEmpty ? 10 : changes.last,
        kind: PrNumberKind.int,
        onChanged: (v) => setState(() => changes.add(v)),
        onCommit: commits.add,
      ),
    ),
  );

  Future<TestGesture> press(WidgetTester tester) async {
    final g = await tester.startGesture(
      tester.getCenter(find.text('priority')),
      kind: PointerDeviceKind.mouse,
    );
    await g.moveBy(const Offset(4, 0)); // starts the drag: +2
    await tester.pump();
    return g;
  }

  testWidgets('maybeOf finds the hooks; null without them', (tester) async {
    PrPlatformHooks? found;
    await pumpFs(
      tester,
      Builder(
        builder: (context) {
          found = PrPlatformHooks.maybeOf(context);
          return const SizedBox();
        },
      ),
    );
    expect(found, isNull);
    final lock = _FakeLock();
    await pumpFs(
      tester,
      PrPlatformHooks(
        pointerLock: lock,
        child: Builder(
          builder: (context) {
            found = PrPlatformHooks.maybeOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(found!.pointerLock, lock);
  });

  testWidgets('a scrub takes the lock and moves by its reports', (
    tester,
  ) async {
    final lock = _FakeLock();
    await pumpFs(tester, number(lock));
    final g = await press(tester);
    expect(lock.log, ['lock']);
    // The drag starts on pointer down and takes the lock at once, so from
    // then on pointer movement is ignored and the lock's reports count.
    expect(changes, isEmpty);
    await g.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(changes, isEmpty);
    lock.move(4);
    lock.move(6);
    await tester.pump();
    expect(changes, [12, 15]);

    await g.up();
    await tester.pump();
    expect(lock.log, ['lock', 'unlock']);
    expect(commits, [15]);
  });

  testWidgets('a refused lock leaves the scrub on pointer events', (
    tester,
  ) async {
    final lock = _FakeLock(grant: false);
    await pumpFs(tester, number(lock));
    final g = await press(tester);
    await g.moveBy(const Offset(4, 0));
    await tester.pump();
    expect(changes, [12, 14]);
    await g.up();
    await tester.pump();
    expect(lock.log, ['lock']); // nothing to unlock
    expect(commits, [14]);
  });

  testWidgets('without hooks the scrub runs on pointer events', (tester) async {
    await pumpFs(tester, number(null));
    final g = await press(tester);
    await g.moveBy(const Offset(4, 0));
    await g.up();
    await tester.pump();
    expect(commits, [14]);
  });

  testWidgets('removing the row mid-scrub releases the lock', (tester) async {
    final lock = _FakeLock();
    await pumpFs(tester, number(lock));
    final g = await press(tester);
    await pumpFs(tester, const SizedBox());
    expect(lock.log, ['lock', 'unlock']);
    await g.up();
  });
}
