import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../helpers.dart';

/// A shell in a stateful parent that keeps the sizes and the collapsed
/// state, like the app.
class _Harness extends StatefulWidget {
  const _Harness({
    this.withBottom = true,
    this.collapsible = true,
    this.onEnd,
    this.bottom,
  });

  final bool withBottom;
  final bool collapsible;
  final ValueChanged<PrShellSizes>? onEnd;
  final Widget? bottom;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  PrShellSizes sizes = PrShellSizes.standard;
  bool collapsed = false;

  void collapse() => setState(() => collapsed = true);

  @override
  Widget build(BuildContext context) => PrEditorShell(
    titleBar: const Center(child: Text('level_1.scene')),
    toolbar: const SizedBox.expand(key: Key('toolbar')),
    left: const SizedBox.expand(key: Key('left')),
    center: const SizedBox.expand(key: Key('center')),
    right: const SizedBox.expand(key: Key('right')),
    bottom: widget.withBottom
        ? widget.bottom ?? const SizedBox.expand(key: Key('bottom'))
        : null,
    bottomCollapsed: collapsed,
    onBottomCollapsedChanged: widget.collapsible
        ? (value) => setState(() => collapsed = value)
        : null,
    statusBar: const SizedBox.expand(key: Key('status')),
    sizes: sizes,
    onSizesChanged: (value) => setState(() => sizes = value),
    onSizesChangeEnd: widget.onEnd,
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget shell, {
  Size window = const Size(1440, 900),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = window;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: PrTheme.dark(), home: shell));
}

Rect _rect(WidgetTester tester, String key) =>
    tester.getRect(find.byKey(Key(key)));

_HarnessState _state(WidgetTester tester) =>
    tester.state<_HarnessState>(find.byType(_Harness));

/// The 1px line of the seam whose hit area contains [at].
Color _seamLine(WidgetTester tester, Offset at) {
  final seams = find.byWidgetPredicate(
    (w) =>
        w is MouseRegion &&
        (w.cursor == SystemMouseCursors.resizeColumn ||
            w.cursor == SystemMouseCursors.resizeRow),
  );
  for (final seam in seams.evaluate()) {
    final box = seam.renderObject! as RenderBox;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (!rect.contains(at)) continue;
    final line = find.descendant(
      of: find.byElementPredicate((e) => e == seam),
      matching: find.byType(ColoredBox),
    );
    return tester.widget<ColoredBox>(line).color;
  }
  throw StateError('No seam at $at');
}

// The seams' centres at the default sizes in a 1440×900 window: the body
// starts at y 70 (title bar 38 + toolbar 32).
const _leftSeam = Offset(260.5, 300);
const _rightSeam = Offset(1440 - 320.5, 300);
const _bottomSeam = Offset(700, 900 - 22 - 220.5);

Future<void> _drag(WidgetTester tester, Offset from, Offset by) async {
  final g = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
  await g.moveBy(by);
  await tester.pump();
  await g.up();
  await tester.pump();
}

void main() {
  group('layout', () {
    testWidgets('regions at 1440×900 with the default sizes', (tester) async {
      await _pump(tester, const _Harness());
      expect(
        tester.getRect(find.text('level_1.scene')).center.dx,
        moreOrLessEquals(720, epsilon: 1),
        reason: 'the title is centred in the window',
      );
      expect(_rect(tester, 'toolbar'), const Rect.fromLTWH(0, 38, 1440, 32));
      expect(_rect(tester, 'left'), const Rect.fromLTWH(0, 70, 260, 808));
      expect(_rect(tester, 'center'), const Rect.fromLTWH(261, 70, 858, 587));
      expect(_rect(tester, 'bottom'), const Rect.fromLTWH(261, 658, 858, 220));
      expect(_rect(tester, 'right'), const Rect.fromLTWH(1120, 70, 320, 808));
      expect(_rect(tester, 'status'), const Rect.fromLTWH(0, 878, 1440, 22));
    });

    testWidgets('the gaps between regions show bg-app', (tester) async {
      await _pump(tester, const _Harness());
      final box = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(PrEditorShell),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(box.color, c.bgApp);
    });

    testWidgets('at 1280×800 the docks shrink to keep the centre', (
      tester,
    ) async {
      await _pump(tester, const _Harness(), window: const Size(1280, 800));
      final center = _rect(tester, 'center');
      expect(center.width, moreOrLessEquals(750));
      expect(center.height, moreOrLessEquals(520));
      expect(_rect(tester, 'left').width, moreOrLessEquals(260 * 528 / 580));
      expect(_rect(tester, 'right').width, moreOrLessEquals(320 * 528 / 580));
      expect(_rect(tester, 'bottom').height, moreOrLessEquals(187));
      expect(
        _state(tester).sizes,
        PrShellSizes.standard,
        reason: 'fitting the window is layout, not a new size',
      );
    });

    testWidgets('no bottom dock: the centre takes the column', (tester) async {
      await _pump(tester, const _Harness(withBottom: false));
      expect(_rect(tester, 'center').height, 808);
      expect(
        find.byWidgetPredicate(
          (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeRow,
        ),
        findsNothing,
      );
    });
  });

  group('seams', () {
    testWidgets('hover draws border-strong, dragging accent-text', (
      tester,
    ) async {
      await _pump(tester, const _Harness());
      expect(_seamLine(tester, _leftSeam), Colors.transparent);

      final m = await mouse(tester);
      await m.moveTo(_leftSeam);
      await tester.pump();
      expect(_seamLine(tester, _leftSeam), c.borderStrong);

      await m.down(_leftSeam);
      await m.moveBy(const Offset(10, 0));
      await tester.pump();
      expect(_seamLine(tester, _leftSeam + const Offset(10, 0)), c.accentText);
      await m.up();
      await tester.pump();
      expect(
        _seamLine(tester, _leftSeam + const Offset(10, 0)),
        c.borderStrong,
      );
    });

    testWidgets('the hit area is 4px around the 1px line', (tester) async {
      await _pump(tester, const _Harness());
      expect(
        () => _seamLine(tester, const Offset(259.1, 300)),
        returnsNormally,
      );
      expect(
        () => _seamLine(tester, const Offset(262.4, 300)),
        returnsNormally,
      );
      expect(() => _seamLine(tester, const Offset(257, 300)), throwsStateError);
      expect(() => _seamLine(tester, const Offset(264, 300)), throwsStateError);
    });

    testWidgets('the left seam resizes the left dock, end once', (
      tester,
    ) async {
      final ends = <PrShellSizes>[];
      await _pump(tester, _Harness(onEnd: ends.add));
      await _drag(tester, _leftSeam, const Offset(40, 0));
      expect(_state(tester).sizes.left, 300);
      expect(_rect(tester, 'left').width, 300);
      expect(_rect(tester, 'center').left, 301);
      expect(ends, [const PrShellSizes(left: 300)]);
    });

    testWidgets('the right seam grows the right dock leftwards', (
      tester,
    ) async {
      await _pump(tester, const _Harness());
      await _drag(tester, _rightSeam, const Offset(-30, 0));
      expect(_state(tester).sizes.right, 350);
      expect(_rect(tester, 'right').left, 1440 - 350);
    });

    testWidgets('dragging clamps to the limits', (tester) async {
      await _pump(tester, const _Harness(), window: const Size(1800, 900));
      await _drag(tester, _leftSeam, const Offset(-200, 0));
      expect(_state(tester).sizes.left, PrShellLimits.standard.minLeft);
      await _drag(tester, const Offset(180.5, 300), const Offset(600, 0));
      expect(_state(tester).sizes.left, PrShellLimits.standard.maxLeft);
    });

    testWidgets('dragging stops where the centre would get too narrow', (
      tester,
    ) async {
      await _pump(tester, const _Harness());
      // 1440 - 2 - 320 - 750 = 368 left for the left dock.
      await _drag(tester, _leftSeam, const Offset(300, 0));
      expect(_state(tester).sizes.left, 368);
      expect(_rect(tester, 'center').width, 750);
    });

    testWidgets('a drag starts from the size on screen', (tester) async {
      await _pump(tester, const _Harness(), window: const Size(1300, 900));
      final shown = _rect(tester, 'left').width;
      expect(shown, lessThan(260));
      await _drag(tester, Offset(shown + 0.5, 300), const Offset(-10, 0));
      expect(_state(tester).sizes.left, moreOrLessEquals(shown - 10));
    });

    testWidgets('the bottom seam resizes the bottom dock', (tester) async {
      await _pump(tester, const _Harness());
      await _drag(tester, _bottomSeam, const Offset(0, -40));
      expect(_state(tester).sizes.bottom, 260);
      expect(_rect(tester, 'bottom').height, 260);
      expect(_rect(tester, 'center').height, 808 - 261);
    });
  });

  group('bottom dock', () {
    testWidgets('collapsed shows the 28px tab strip, laid out expanded', (
      tester,
    ) async {
      await _pump(tester, const _Harness());
      _state(tester).collapse();
      await tester.pump();
      expect(_rect(tester, 'center').height, 808 - 29);
      expect(
        _rect(tester, 'bottom'),
        const Rect.fromLTWH(261, 878 - 28, 858, 220),
        reason: 'the dock keeps its expanded layout under the clip',
      );
    });

    testWidgets('dragging below half the minimum collapses, up expands', (
      tester,
    ) async {
      await _pump(tester, const _Harness());
      await _drag(tester, _bottomSeam, const Offset(0, 200));
      expect(_state(tester).collapsed, isTrue);
      expect(
        _state(tester).sizes.bottom,
        220,
        reason: 'the expanded height is kept for later',
      );

      await _drag(tester, const Offset(700, 878 - 28.5), const Offset(0, -150));
      expect(_state(tester).collapsed, isFalse);
      expect(_state(tester).sizes.bottom, 28 + 150);
    });

    testWidgets('without onBottomCollapsedChanged the seam only resizes', (
      tester,
    ) async {
      await _pump(tester, const _Harness(collapsible: false));
      await _drag(tester, _bottomSeam, const Offset(0, 200));
      expect(_state(tester).collapsed, isFalse);
      expect(_state(tester).sizes.bottom, PrShellLimits.standard.minBottom);
    });

    testWidgets('collapsing keeps the dock state', (tester) async {
      await _pump(tester, const _Harness(bottom: _Counter()));
      await tester.tap(find.text('0'));
      await tester.pump();
      _state(tester).collapse();
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
    });
  });

  testWidgets('debug states force the seam lines', (tester) async {
    await _pump(
      tester,
      const PrDebugStates(
        states: {WidgetState.hovered},
        part: 'seam-right',
        child: PrDebugStates(
          states: {WidgetState.dragged},
          part: 'seam-bottom',
          child: _Harness(),
        ),
      ),
    );
    expect(_seamLine(tester, _leftSeam), Colors.transparent);
    expect(_seamLine(tester, _rightSeam), c.borderStrong);
    expect(_seamLine(tester, _bottomSeam), c.accentText);
  });
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: GestureDetector(
      onTap: () => setState(() => count++),
      child: Text('$count'),
    ),
  );
}
