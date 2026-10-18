import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../helpers.dart';

final changes = <(double?, double?)>[];
final commits = <(double?, double?)>[];

class _Harness extends StatefulWidget {
  const _Harness({this.mixedX = false, this.enabled = true});

  final bool mixedX;
  final bool enabled;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  double? x = 412.5;
  double? y = 288;
  late bool mixedX = widget.mixedX;

  @override
  Widget build(BuildContext context) => PrVector2Property(
    label: 'position',
    x: mixedX ? null : x,
    y: y,
    mixedX: mixedX,
    enabled: widget.enabled,
    invalidMessage: 'Expected a number',
    onChanged: (nx, ny) {
      changes.add((nx, ny));
      setState(() {
        if (nx != null) {
          x = nx;
          mixedX = false;
        }
        y = ny;
      });
    },
    onCommit: (nx, ny) => commits.add((nx, ny)),
  );
}

final _x = find.text('X');
final _y = find.text('Y');
final _label = find.text('position');
Finder _fieldOf(Finder letter) =>
    find.ancestor(of: letter, matching: find.byType(PrFieldBox));

void main() {
  setUp(() {
    changes.clear();
    commits.clear();
  });

  testWidgets('axis letters in axis-x / axis-y', (tester) async {
    await pumpFs(tester, const _Harness());
    expect(textColor(tester, 'X'), c.axisX);
    expect(textColor(tester, 'Y'), c.axisY);
    expect(fieldText(tester, 0), '412.5');
    expect(fieldText(tester, 1), '288.0');
  });

  testWidgets('dragging a letter scrubs that axis only', (tester) async {
    await pumpFs(tester, const _Harness());
    await mouseDrag(tester, _y, 26);
    expect(commits, [(412.5, 301.0)]);
    expect(fieldText(tester, 1), '301.0');
  });

  testWidgets('dragging the label scrubs both', (tester) async {
    await pumpFs(tester, const _Harness());
    await mouseDrag(tester, _label, 4);
    expect(commits, [(414.5, 290.0)]);
  });

  testWidgets('only the scrubbed field gets the accent border', (tester) async {
    await pumpFs(tester, const _Harness());
    final g = await tester.startGesture(
      tester.getCenter(_y),
      kind: PointerDeviceKind.mouse,
    );
    await g.moveBy(const Offset(10, 0));
    await tester.pump();
    expect(fieldBorder(tester, _fieldOf(_y)), c.accentText);
    expect(fieldBorder(tester, _fieldOf(_x)), isNot(c.accentText));
    expect(textColor(tester, 'position'), isNot(c.accentText));
    await g.up();
  });

  testWidgets('mixed X: "—" in X only; typing Y passes null for X', (
    tester,
  ) async {
    await pumpFs(tester, const _Harness(mixedX: true));
    expect(fieldText(tester, 0), '—');
    expect(fieldText(tester, 1), '288.0');
    await tester.tap(find.byType(EditableText).at(1));
    await tester.pump();
    await tester.enterText(find.byType(EditableText).at(1), '10');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(commits, [(null, 10.0)]);
  });

  testWidgets('mixed X: the label scrubs Y only', (tester) async {
    await pumpFs(tester, const _Harness(mixedX: true));
    await mouseDrag(tester, _label, 4);
    expect(commits, [(null, 290.0)]);
    expect(fieldText(tester, 0), '—');
  });

  testWidgets('Tab order X → Y', (tester) async {
    await pumpFs(tester, const _Harness());
    await tester.tap(find.byType(EditableText).at(0));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final y = tester.widget<EditableText>(find.byType(EditableText).at(1));
    expect(y.focusNode.hasFocus, isTrue);
  });

  testWidgets('an invalid Y marks Y and the label, not X', (tester) async {
    await pumpFs(tester, const _Harness());
    await tester.tap(find.byType(EditableText).at(1));
    await tester.pump();
    await tester.enterText(find.byType(EditableText).at(1), '2 88');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(fieldBorder(tester, _fieldOf(_y)), c.error);
    expect(fieldBorder(tester, _fieldOf(_x)), isNot(c.error));
    expect(textColor(tester, 'position'), c.error);
    expect(commits, isEmpty);
  });

  testWidgets('disabled: letters text-disabled, no scrub', (tester) async {
    await pumpFs(tester, const _Harness(enabled: false));
    expect(textColor(tester, 'X'), c.textDisabled);
    await mouseDrag(tester, _x, 20);
    expect(changes, isEmpty);
  });

  testWidgets('forced states per axis part', (tester) async {
    await pumpFs(
      tester,
      const PrDebugStates(
        part: 'y',
        states: {WidgetState.dragged},
        child: _Harness(),
      ),
    );
    expect(fieldBorder(tester, _fieldOf(_y)), c.accentText);
    expect(fieldBorder(tester, _fieldOf(_x)), c.borderControl);
  });

  group('aspect lock', () {
    testWidgets('no button unless aspectLocked is set', (tester) async {
      await pumpFs(tester, const _Harness());
      expect(find.byType(PrToggleButton), findsNothing);
      await pumpFs(tester, const _Locked(locked: false));
      expect(find.byType(PrToggleButton), findsOneWidget);
      expect(tester.getSize(find.byType(PrToggleButton)).height, 20);
      expect(find.byIcon(PrIcons.link), findsOneWidget);
    });

    testWidgets('the button toggles the lock', (tester) async {
      await pumpFs(tester, const _Locked(locked: false));
      await tester.tap(find.byType(PrToggleButton));
      await tester.pump();
      expect(
        tester.widget<PrToggleButton>(find.byType(PrToggleButton)).value,
        isTrue,
      );
    });

    testWidgets('editing X scales Y', (tester) async {
      await pumpFs(tester, const _Locked());
      await tester.tap(find.byType(EditableText).first);
      await tester.pump();
      await tester.enterText(find.byType(EditableText).first, '3');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(commits, [(3.0, 6.0)]);
      expect(fieldText(tester, 1), '6.0');
    });

    testWidgets('scrubbing Y scales X; one commit', (tester) async {
      await pumpFs(tester, const _Locked());
      await mouseDrag(tester, _y, 8, steps: 2); // 4 steps of 1
      expect(changes.last, (3.0, 6.0));
      expect(commits, [(3.0, 6.0)]);
    });

    testWidgets('scrubbing the label scales both', (tester) async {
      await pumpFs(tester, const _Locked());
      await mouseDrag(tester, _label, 4); // X +2
      expect(commits, [(3.0, 6.0)]);
    });

    testWidgets('unlocked, the axes change on their own', (tester) async {
      await pumpFs(tester, const _Locked(locked: false));
      await mouseDrag(tester, _y, 8, steps: 2);
      expect(commits, [(1.0, 6.0)]);
    });

    testWidgets('an axis at zero has no ratio to keep', (tester) async {
      await pumpFs(tester, const _Locked(x: 0));
      await mouseDrag(tester, _y, 8, steps: 2);
      expect(commits, [(0.0, 6.0)]);
    });
  });
}

/// A `scale`-like row with the aspect lock, following its callbacks.
class _Locked extends StatefulWidget {
  const _Locked({this.locked = true, this.x = 1});

  final bool locked;
  final double x;

  @override
  State<_Locked> createState() => _LockedState();
}

class _LockedState extends State<_Locked> {
  late double? x = widget.x;
  double? y = 2;
  late bool locked = widget.locked;

  @override
  Widget build(BuildContext context) => PrVector2Property(
    label: 'position',
    x: x,
    y: y,
    aspectLocked: locked,
    aspectLockTooltip: 'Lock aspect ratio',
    onAspectLockChanged: (v) => setState(() => locked = v),
    onChanged: (nx, ny) {
      changes.add((nx, ny));
      setState(() {
        x = nx;
        y = ny;
      });
    },
    onCommit: (nx, ny) => commits.add((nx, ny)),
  );
}
