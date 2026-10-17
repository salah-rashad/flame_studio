import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
  Widget build(BuildContext context) => FsVector2Property(
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
    find.ancestor(of: letter, matching: find.byType(FsFieldBox));

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
      const FsDebugStates(
        part: 'y',
        states: {WidgetState.dragged},
        child: _Harness(),
      ),
    );
    expect(fieldBorder(tester, _fieldOf(_y)), c.accentText);
    expect(fieldBorder(tester, _fieldOf(_x)), c.borderControl);
  });
}
