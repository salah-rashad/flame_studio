import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_ui/pyro_ui.dart';
import 'package:pyro_ui/src/foundation/focus_ring.dart';

import '../helpers.dart';

/// Records the states PrInteractive hands its builder.
Set<WidgetState> _last = {};

Widget _target({
  VoidCallback? onPressed,
  bool selected = false,
  bool error = false,
}) => PrInteractive(
  onPressed: onPressed,
  selected: selected,
  error: error,
  builder: (context, states) {
    _last = states;
    return PrFocusRing.outside(
      visible: states.contains(WidgetState.focused),
      child: const SizedBox(width: 40, height: 24),
    );
  },
);

void main() {
  group('PrInteractive', () {
    testWidgets('disabled when onPressed is null', (tester) async {
      await pumpFs(tester, _target());
      expect(_last, contains(WidgetState.disabled));
      await pumpFs(tester, _target(onPressed: () {}));
      expect(_last, isNot(contains(WidgetState.disabled)));
    });

    testWidgets('selected and error come from the flags', (tester) async {
      await pumpFs(
        tester,
        _target(onPressed: () {}, selected: true, error: true),
      );
      expect(_last, containsAll([WidgetState.selected, WidgetState.error]));
    });

    testWidgets('hover follows a mouse', (tester) async {
      await pumpFs(tester, _target(onPressed: () {}));
      final m = await mouse(tester);
      await hover(tester, m, find.byType(PrInteractive));
      expect(_last, contains(WidgetState.hovered));
      await m.moveTo(const Offset(300, 500));
      await tester.pump();
      expect(_last, isNot(contains(WidgetState.hovered)));
    });

    testWidgets('pressed while down; a click inside calls onPressed', (
      tester,
    ) async {
      var presses = 0;
      await pumpFs(tester, _target(onPressed: () => presses++));
      final g = await tester.startGesture(
        tester.getCenter(find.byType(PrInteractive)),
      );
      await tester.pump();
      expect(_last, contains(WidgetState.pressed));
      await g.up();
      await tester.pump();
      expect(_last, isNot(contains(WidgetState.pressed)));
      expect(presses, 1);
    });

    testWidgets('a press that drags away is cancelled', (tester) async {
      var presses = 0;
      await pumpFs(tester, _target(onPressed: () => presses++));
      final g = await tester.startGesture(
        tester.getCenter(find.byType(PrInteractive)),
      );
      await g.moveBy(const Offset(30, 0));
      await tester.pump();
      expect(_last, isNot(contains(WidgetState.pressed)));
      await g.moveBy(const Offset(-30, 0));
      await g.up();
      expect(presses, 0);
    });

    testWidgets('disabled controls ignore clicks', (tester) async {
      await pumpFs(tester, _target());
      await tester.tap(find.byType(PrInteractive));
      await tester.pump();
      expect(_last, isNot(contains(WidgetState.pressed)));
    });

    testWidgets('Tab focus shows the ring; Enter and Space activate', (
      tester,
    ) async {
      var presses = 0;
      await pumpFs(tester, _target(onPressed: () => presses++));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_last, contains(WidgetState.focused));
      expect(
        hasPainter<PrEdgePainter>(tester, find.byType(PrInteractive)),
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(presses, 2);
    });

    testWidgets('a click never shows the ring; a key press then does', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await pumpFs(
        tester,
        PrInteractive(
          onPressed: () {},
          focusNode: node,
          requestFocusOnPress: true,
          builder: (context, states) {
            _last = states;
            return const SizedBox(width: 40, height: 24);
          },
        ),
      );
      await tester.tap(find.byType(PrInteractive));
      await tester.pump();
      expect(node.hasFocus, isTrue);
      expect(_last, isNot(contains(WidgetState.focused)));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(_last, contains(WidgetState.focused));
    });

    testWidgets('modifier keys alone do not show the ring', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await pumpFs(
        tester,
        PrInteractive(
          onPressed: () {},
          focusNode: node,
          requestFocusOnPress: true,
          builder: (context, states) {
            _last = states;
            return const SizedBox(width: 40, height: 24);
          },
        ),
      );
      await tester.tap(find.byType(PrInteractive));
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(_last, isNot(contains(WidgetState.focused)));
    });

    testWidgets('not focusable inside roving groups', (tester) async {
      await pumpFs(
        tester,
        PrInteractive(
          onPressed: () {},
          focusable: false,
          builder: (context, states) {
            _last = states;
            return const SizedBox(width: 40, height: 24);
          },
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_last, isNot(contains(WidgetState.focused)));
    });

    testWidgets('disabled controls are skipped by Tab', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await pumpFs(
        tester,
        PrInteractive(
          focusNode: node,
          builder: (context, states) => const SizedBox(width: 40, height: 24),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(node.hasFocus, isFalse);
    });

    testWidgets('focusableWhenDisabled: Tab reaches it, the keys do nothing', (
      tester,
    ) async {
      var activated = 0;
      final node = FocusNode();
      addTearDown(node.dispose);
      final semantics = tester.ensureSemantics();
      await pumpFs(
        tester,
        PrInteractive(
          focusNode: node,
          focusableWhenDisabled: true,
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.keyR): ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) => activated++,
            ),
          },
          semanticsLabel: 'Run game',
          builder: (context, states) {
            _last = states;
            return const SizedBox(width: 40, height: 24);
          },
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(node.hasFocus, isTrue);
      expect(_last, containsAll({WidgetState.focused, WidgetState.disabled}));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      expect(activated, 0);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Run game')),
        isSemantics(
          label: 'Run game',
          hasEnabledState: true,
          isEnabled: false,
          isFocusable: true,
          isFocused: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('PrDebugStates forces states, optionally per part', (
      tester,
    ) async {
      await pumpFs(
        tester,
        PrDebugStates(
          states: const {WidgetState.hovered, WidgetState.pressed},
          child: _target(onPressed: () {}),
        ),
      );
      expect(_last, containsAll([WidgetState.hovered, WidgetState.pressed]));

      await pumpFs(
        tester,
        PrDebugStates(
          part: 'label',
          states: const {WidgetState.hovered},
          child: _target(onPressed: () {}),
        ),
      );
      expect(_last, isNot(contains(WidgetState.hovered)));
    });

    testWidgets('nested PrDebugStates: the nearest that applies wins', (
      tester,
    ) async {
      await pumpFs(
        tester,
        PrDebugStates(
          states: const {WidgetState.pressed},
          child: PrDebugStates(
            part: 'label',
            states: const {WidgetState.hovered},
            child: _target(onPressed: () {}),
          ),
        ),
      );
      // The 'label' one is skipped; the global one further up applies.
      expect(_last, contains(WidgetState.pressed));
      expect(_last, isNot(contains(WidgetState.hovered)));
    });
  });

  test('PrStateColor picks the first matching state', () {
    final colors = {
      WidgetState.disabled: c.textDisabled,
      WidgetState.pressed: c.surfacePressed,
      WidgetState.hovered: c.surfaceHover,
    };
    Color resolve(Set<WidgetState> s) =>
        PrStateColor.resolve(s, colors, fallback: c.surfacePanel);
    expect(resolve({}), c.surfacePanel);
    expect(resolve({WidgetState.hovered}), c.surfaceHover);
    expect(
      resolve({WidgetState.hovered, WidgetState.pressed}),
      c.surfacePressed,
    );
    expect(
      resolve({WidgetState.pressed, WidgetState.disabled}),
      c.textDisabled,
    );
  });
}
