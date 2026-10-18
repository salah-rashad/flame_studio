import 'dart:async';

import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flame_studio_ui/src/foundation/focus_ring.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

const _peach = Color(0xFFFFD7A8);

final _changes = <Color>[];
final _commits = <Color>[];

/// A picker whose value follows its callbacks.
class _Harness extends StatefulWidget {
  const _Harness({this.initial = _peach, this.recent = const []});

  final Color initial;
  final List<Color> recent;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late Color value = widget.initial;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: FsColorPicker(
        value: value,
        recentColors: widget.recent,
        eyedropperTooltip: 'Pick from the screen',
        areaLabel: 'Saturation and brightness',
        hueLabel: 'Hue',
        onChanged: (v) {
          _changes.add(v);
          setState(() => value = v);
        },
        onCommit: _commits.add,
      ),
    ),
  );
}

final _picker = find.byType(FsColorPicker);

/// The SV area and the hue bar, in that order.
Finder _pads() => find.descendant(
  of: _picker,
  matching: find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter != null && w.size.height > 0,
  ),
);

/// Whether the focus ring is drawn around [pad] (it wraps the painter).
bool _ringOn(WidgetTester tester, Finder pad) => find
    .ancestor(
      of: pad,
      matching: find.byWidgetPredicate(
        (w) =>
            w is CustomPaint &&
            (w.painter is FsEdgePainter ||
                w.foregroundPainter is FsEdgePainter),
      ),
    )
    .evaluate()
    .isNotEmpty;

String _hex(Color c) =>
    (c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

void main() {
  setUp(() {
    _changes.clear();
    _commits.clear();
  });

  testWidgets('232px on the overlay surface; hex and alpha fields', (
    tester,
  ) async {
    await pumpFs(tester, const _Harness(), width: 400);
    expect(tester.getSize(_picker).width, 232);
    final box = decorationIn(tester, _picker);
    expect(box.color, c.surfaceOverlay);
    expect(box.borderRadius, FsRadii.md);
    expect(fieldText(tester, 0), 'FFD7A8');
    expect(fieldText(tester, 1), '100');
    expect(find.text('%'), findsOneWidget);
    // No eyedropper without the platform hook.
    expect(find.byIcon(FsIcons.pipette), findsNothing);
    expect(tester.getSize(_pads().first).height, 120);
  });

  testWidgets('dragging in the SV area: continuous, one commit', (
    tester,
  ) async {
    await pumpFs(tester, const _Harness(), width: 400);
    final sv = tester.getRect(_pads().first);
    final gesture = await tester.startGesture(
      sv.center,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(sv.topRight + const Offset(20, -20)); // clamped
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(_changes, isNotEmpty);
    // Full saturation and value at the peach's hue (32°).
    final hsv = HSVColor.fromColor(_changes.last);
    expect(hsv.saturation, closeTo(1, 0.01));
    expect(hsv.value, closeTo(1, 0.01));
    expect(hsv.hue, closeTo(HSVColor.fromColor(_peach).hue, 1));
    expect(_commits, [_changes.last]);
    expect(fieldText(tester, 0), _hex(_changes.last));
  });

  testWidgets('dragging the hue bar sets the hue', (tester) async {
    await pumpFs(tester, const _Harness(), width: 400);
    final hue = tester.getRect(_pads().last);
    await tester.dragFrom(hue.centerLeft, Offset(hue.width / 2, 0));
    await tester.pump();
    expect(HSVColor.fromColor(_commits.single).hue, closeTo(180, 2));
  });

  testWidgets('a click in the SV area commits too', (tester) async {
    await pumpFs(tester, const _Harness(), width: 400);
    final sv = tester.getRect(_pads().first);
    await tester.tapAt(sv.bottomLeft + const Offset(1, -1));
    await tester.pump();
    expect(_commits, hasLength(1));
    expect(HSVColor.fromColor(_commits.single).value, closeTo(0, 0.02));
  });

  group('keyboard', () {
    final start = HSVColor.fromColor(_peach);
    HSVColor committed() => HSVColor.fromColor(_commits.last);
    Future<void> press(
      WidgetTester tester,
      LogicalKeyboardKey key, {
      bool shift = false,
    }) async {
      if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(key);
      if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pump();
    }

    testWidgets('SV area: Tab reaches it first; arrows step 1%, Shift 10%, '
        'one commit each', (tester) async {
      await pumpFs(tester, const _Harness());
      await press(tester, LogicalKeyboardKey.tab);
      expect(_ringOn(tester, _pads().first), isTrue);

      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(_commits, hasLength(1));
      expect(committed().saturation, closeTo(start.saturation + 0.01, 0.005));

      await press(tester, LogicalKeyboardKey.arrowDown, shift: true);
      expect(_commits, hasLength(2));
      expect(committed().value, closeTo(start.value - 0.1, 0.005));

      // Already at full brightness? Up clamps; no change, no commit.
      await press(tester, LogicalKeyboardKey.arrowUp, shift: true);
      await press(tester, LogicalKeyboardKey.arrowUp);
      expect(committed().value, closeTo(1, 0.005));
      expect(_commits, hasLength(3));
    });

    testWidgets('hue: → ↑ up 1°, ← ↓ down, Shift 10°', (tester) async {
      await pumpFs(tester, const _Harness());
      await press(tester, LogicalKeyboardKey.tab);
      await press(tester, LogicalKeyboardKey.tab);
      expect(_ringOn(tester, _pads().last), isTrue);

      await press(tester, LogicalKeyboardKey.arrowRight, shift: true);
      expect(_commits, hasLength(1));
      expect(committed().hue, closeTo(start.hue + 10, 1));
      await press(tester, LogicalKeyboardKey.arrowLeft);
      expect(committed().hue, closeTo(start.hue + 9, 1));

      await press(tester, LogicalKeyboardKey.arrowUp, shift: true);
      expect(committed().hue, closeTo(start.hue + 19, 1));
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(committed().hue, closeTo(start.hue + 18, 1));
      expect(_commits, hasLength(4));
      // The arrows stay with the slider: focus didn't move.
      expect(_ringOn(tester, _pads().last), isTrue);
    });

    testWidgets('a click focuses the SV area without the ring', (tester) async {
      await pumpFs(tester, const _Harness());
      final m = await mouse(tester);
      await m.down(tester.getCenter(_pads().first));
      await m.up();
      await tester.pump();
      expect(_ringOn(tester, _pads().first), isFalse);
      final before = _commits.length;
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(_commits, hasLength(before + 1));
    });

    testWidgets('screen readers get two sliders with values', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpFs(tester, const _Harness());
      final s = (start.saturation * 100).round();
      final v = (start.value * 100).round();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Saturation and brightness')),
        isSemantics(
          isSlider: true,
          value: '$s%, $v%',
          increasedValue: '${s + 1}%, $v%',
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Hue')),
        isSemantics(isSlider: true, value: '${start.hue.round()}°'),
      );
      semantics.dispose();
    });
  });

  testWidgets('the hue survives black and grey', (tester) async {
    await pumpFs(tester, const _Harness(), width: 400);
    final sv = tester.getRect(_pads().first);
    // To black and back up: the peach's hue comes back.
    await tester.dragFrom(
      sv.topRight + const Offset(-1, 1),
      Offset(0, sv.height + 10),
    );
    await tester.pump();
    await tester.dragFrom(
      sv.bottomRight + const Offset(-1, -1),
      Offset(0, -sv.height - 10),
    );
    await tester.pump();
    expect(
      HSVColor.fromColor(_commits.last).hue,
      closeTo(HSVColor.fromColor(_peach).hue, 1),
    );
  });

  testWidgets('hex: Enter commits with the alpha kept; bad text is an '
      'error', (tester) async {
    await pumpFs(
      tester,
      _Harness(initial: _peach.withValues(alpha: 0.5)),
      width: 400,
    );
    final hex = find.byType(EditableText).first;
    await tester.tap(hex);
    await tester.pump();
    await tester.enterText(hex, '3366cc');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_commits.single.toARGB32() & 0xFFFFFF, 0x3366CC);
    expect(_commits.single.a, closeTo(0.5, 0.01));
    expect(fieldText(tester, 0), '3366CC');

    await tester.enterText(hex, 'FFD7A');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_commits, hasLength(1));
    expect(fieldBorder(tester, find.byType(FsFieldBox).first), c.error);
  });

  testWidgets('alpha: a typed percentage', (tester) async {
    await pumpFs(tester, const _Harness(), width: 400);
    final alpha = find.byType(EditableText).last;
    await tester.tap(alpha);
    await tester.pump();
    await tester.enterText(alpha, '25');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_commits.single.a, closeTo(0.25, 0.01));
    expect(_commits.single.toARGB32() & 0xFFFFFF, 0xFFD7A8);
  });

  testWidgets('recent colours: a click picks one', (tester) async {
    const sky = Color(0xFF7CC8F0);
    await pumpFs(
      tester,
      const _Harness(recent: [Color(0xFFFFFFFF), sky]),
      width: 400,
    );
    final swatches = find.descendant(
      of: _picker,
      matching: find.byWidgetPredicate(
        (w) => w is FsInteractive && w.semanticsLabel == '#7CC8F0',
      ),
    );
    expect(tester.getSize(swatches), const Size(20, 16));
    await tester.tap(swatches);
    await tester.pump();
    expect(_commits, [sky]);
    expect(fieldText(tester, 0), '7CC8F0');
  });

  testWidgets('eyedropper: shown with the hook; samples with the alpha '
      'kept', (tester) async {
    final sampled = Completer<Color?>();
    await pumpFs(
      tester,
      FsPlatformHooks(
        sampleScreenColor: () => sampled.future,
        child: _Harness(initial: _peach.withValues(alpha: 0.4)),
      ),
      width: 400,
    );
    expect(find.byIcon(FsIcons.pipette), findsOneWidget);
    await tester.tap(find.byIcon(FsIcons.pipette));
    sampled.complete(const Color(0xFF6CC04A));
    await tester.pump();
    expect(_commits.single.toARGB32() & 0xFFFFFF, 0x6CC04A);
    expect(_commits.single.a, closeTo(0.4, 0.01));
  });
}
