import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

Widget _target(String message, {Key? key, SingleActivator? shortcut}) =>
    FsTooltip(
      message: message,
      shortcut: shortcut,
      child: SizedBox(key: key, width: 24, height: 24),
    );

Future<TestGesture> _hoverAt(WidgetTester tester, Finder finder) async {
  final m = await mouse(tester);
  await m.moveTo(tester.getCenter(finder));
  await tester.pump();
  return m;
}

void main() {
  const move = 'Move tool';
  final a = find.byKey(const Key('a'));
  final b = find.byKey(const Key('b'));

  Widget pair({bool group = false}) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _target(move, key: const Key('a')),
        const SizedBox(width: 2),
        _target('Rotate tool', key: const Key('b')),
      ],
    );
    return Padding(
      padding: const EdgeInsets.all(40),
      child: group ? FsTooltipGroup(child: row) : row,
    );
  }

  testWidgets('appears after 500ms of hover, not before', (tester) async {
    await pumpFs(tester, pair());
    await _hoverAt(tester, a);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(move), findsNothing);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text(move), findsOneWidget);
  });

  testWidgets('below the anchor with a 4px gap, left edges aligned', (
    tester,
  ) async {
    await pumpFs(tester, pair());
    await _hoverAt(tester, a);
    await tester.pump(FsTooltip.delay);
    await tester.pump(const Duration(milliseconds: 150));
    final box = find
        .ancestor(of: find.text(move), matching: find.byType(Container))
        .first;
    expect(tester.getTopLeft(box).dy, tester.getBottomLeft(a).dy + 4);
    expect(tester.getTopLeft(box).dx, tester.getTopLeft(a).dx);
  });

  testWidgets('tokens: overlay surface, border, radius, small text', (
    tester,
  ) async {
    await pumpFs(tester, pair());
    await _hoverAt(tester, a);
    await tester.pump(FsTooltip.delay);
    await tester.pump(const Duration(milliseconds: 150));
    final box = find
        .ancestor(of: find.text(move), matching: find.byType(Container))
        .first;
    final d = tester.widget<Container>(box).decoration! as BoxDecoration;
    expect(d.color, c.surfaceOverlay);
    expect((d.border! as Border).top.color, c.borderOverlay);
    expect(d.borderRadius, FsRadii.sm);
    expect(d.boxShadow, FsShadows.dark.tooltip);
    final style = tester.widget<Text>(find.text(move)).style!;
    expect(style.color, c.textPrimary);
    expect(style.fontSize, FsText.small.fontSize);
  });

  testWidgets('moving to a neighbour shows its tooltip at once', (
    tester,
  ) async {
    await pumpFs(tester, pair());
    final m = await _hoverAt(tester, a);
    await tester.pump(FsTooltip.delay);
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text(move), findsOneWidget);
    await m.moveTo(tester.getCenter(b));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Rotate tool'), findsOneWidget);
  });

  testWidgets('with a group, tooltips stay warm for 300ms after hiding', (
    tester,
  ) async {
    await pumpFs(tester, pair(group: true));
    final m = await _hoverAt(tester, a);
    await tester.pump(FsTooltip.delay);
    await tester.pump(const Duration(milliseconds: 150));
    // Leave both and let the first tooltip fade out.
    await m.moveTo(const Offset(300, 500));
    await tester.pumpAndSettle();
    expect(find.text(move), findsNothing);
    // Still warm: the neighbour shows without the 500ms delay.
    await m.moveTo(tester.getCenter(b));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Rotate tool'), findsOneWidget);
    await m.moveTo(const Offset(300, 500));
    await tester.pumpAndSettle();
    await tester.pump(FsTooltipGroup.cooldown);
  });

  testWidgets('without a recent tooltip, the delay applies again', (
    tester,
  ) async {
    await pumpFs(tester, pair(group: true));
    final m = await _hoverAt(tester, a);
    await tester.pump(FsTooltip.delay);
    await tester.pump(const Duration(milliseconds: 150));
    await m.moveTo(const Offset(300, 500));
    await tester.pumpAndSettle();
    await tester.pump(FsTooltipGroup.cooldown);
    await m.moveTo(tester.getCenter(b));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Rotate tool'), findsNothing);
    await tester.pump(FsTooltip.delay);
    expect(find.text('Rotate tool'), findsOneWidget);
  });

  testWidgets('keyboard focus shows it after the delay; leaving hides it', (
    tester,
  ) async {
    await pumpFs(
      tester,
      Padding(
        padding: const EdgeInsets.all(40),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FsTooltip(
              message: move,
              child: FsIconButton(
                icon: FsIcons.move,
                tooltip: '',
                onPressed: () {},
              ),
            ),
            FsIconButton(icon: FsIcons.rotate, tooltip: '', onPressed: () {}),
          ],
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(move), findsNothing);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text(move), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(find.text(move), findsNothing);
  });

  testWidgets('hides on press and on Esc', (tester) async {
    await pumpFs(tester, pair());
    await _hoverAt(tester, a);
    await tester.pump(FsTooltip.delay);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text(move), findsNothing);

    await pumpFs(tester, pair());
    final g = await tester.startGesture(
      tester.getCenter(a),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(FsTooltip.delay);
    await tester.pump(const Duration(milliseconds: 150));
    await g.up();
    await tester.pumpAndSettle();
    expect(find.text(move), findsNothing);
  });

  testWidgets('shortcut in a key cap; details as secondary lines', (
    tester,
  ) async {
    await pumpFs(
      tester,
      const Padding(
        padding: EdgeInsets.all(40),
        child: FsTooltip(
          message: 'Stop',
          shortcut: SingleActivator(LogicalKeyboardKey.period, meta: true),
          details: ['nothing is running'],
          child: SizedBox(key: Key('a'), width: 24, height: 24),
        ),
      ),
    );
    await _hoverAt(tester, a);
    await tester.pump(FsTooltip.delay);
    await tester.pump(const Duration(milliseconds: 150));
    final cap = find.byType(FsShortcutLabel);
    expect(tester.widget<FsShortcutLabel>(cap).style, FsShortcutStyle.keycap);
    expect(textColor(tester, 'nothing is running'), c.textSecondary);
  });

  testWidgets('error tooltips: error edge, icon and text', (tester) async {
    await pumpFs(
      tester,
      const Padding(
        padding: EdgeInsets.all(40),
        child: FsTooltip(
          message: 'Expected a number',
          error: true,
          child: SizedBox(key: Key('a'), width: 24, height: 24),
        ),
      ),
    );
    await _hoverAt(tester, a);
    await tester.pump(FsTooltip.delay);
    await tester.pump(const Duration(milliseconds: 150));
    expect(textColor(tester, 'Expected a number'), c.error);
    expect(find.byIcon(FsIcons.alertCircle), findsOneWidget);
  });

  testWidgets('semantics carry the message', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpFs(tester, pair());
    expect(tester.getSemantics(a), matchesSemantics(tooltip: move));
    handle.dispose();
  });

  testWidgets('forced with part "tooltip": drawn below without hover', (
    tester,
  ) async {
    await pumpFs(
      tester,
      FsDebugStates(
        part: 'tooltip',
        states: const {WidgetState.hovered},
        child: _target(move, key: const Key('a')),
      ),
    );
    expect(find.text(move), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(move)).dy,
      greaterThan(tester.getBottomLeft(a).dy),
    );
    // Global forced states don't open tooltips.
    await pumpFs(
      tester,
      FsDebugStates(
        states: const {WidgetState.hovered},
        child: _target(move, key: const Key('a')),
      ),
    );
    expect(find.text(move), findsNothing);
  });
}
