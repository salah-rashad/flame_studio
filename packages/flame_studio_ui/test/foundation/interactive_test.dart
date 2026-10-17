import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flame_studio_ui/src/foundation/focus_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Records the states FsInteractive hands its builder.
Set<WidgetState> _last = {};

Widget _target({
  VoidCallback? onPressed,
  bool selected = false,
  bool error = false,
}) => FsInteractive(
  onPressed: onPressed,
  selected: selected,
  error: error,
  builder: (context, states) {
    _last = states;
    return FsFocusRing.outside(
      visible: states.contains(WidgetState.focused),
      child: const SizedBox(width: 40, height: 24),
    );
  },
);

void main() {
  group('FsInteractive', () {
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
      await hover(tester, m, find.byType(FsInteractive));
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
        tester.getCenter(find.byType(FsInteractive)),
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
        tester.getCenter(find.byType(FsInteractive)),
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
      await tester.tap(find.byType(FsInteractive));
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
        hasPainter<FsEdgePainter>(tester, find.byType(FsInteractive)),
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
        FsInteractive(
          onPressed: () {},
          focusNode: node,
          requestFocusOnPress: true,
          builder: (context, states) {
            _last = states;
            return const SizedBox(width: 40, height: 24);
          },
        ),
      );
      await tester.tap(find.byType(FsInteractive));
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
        FsInteractive(
          onPressed: () {},
          focusNode: node,
          requestFocusOnPress: true,
          builder: (context, states) {
            _last = states;
            return const SizedBox(width: 40, height: 24);
          },
        ),
      );
      await tester.tap(find.byType(FsInteractive));
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(_last, isNot(contains(WidgetState.focused)));
    });

    testWidgets('not focusable inside roving groups', (tester) async {
      await pumpFs(
        tester,
        FsInteractive(
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

    testWidgets('FsDebugStates forces states, optionally per part', (
      tester,
    ) async {
      await pumpFs(
        tester,
        FsDebugStates(
          states: const {WidgetState.hovered, WidgetState.pressed},
          child: _target(onPressed: () {}),
        ),
      );
      expect(_last, containsAll([WidgetState.hovered, WidgetState.pressed]));

      await pumpFs(
        tester,
        FsDebugStates(
          part: 'label',
          states: const {WidgetState.hovered},
          child: _target(onPressed: () {}),
        ),
      );
      expect(_last, isNot(contains(WidgetState.hovered)));
    });
  });

  test('FsStateColor picks the first matching state', () {
    final colors = {
      WidgetState.disabled: c.textDisabled,
      WidgetState.pressed: c.surfacePressed,
      WidgetState.hovered: c.surfaceHover,
    };
    Color resolve(Set<WidgetState> s) =>
        FsStateColor.resolve(s, colors, fallback: c.surfacePanel);
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
