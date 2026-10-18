import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

const _radius = BorderRadius.all(Radius.circular(3));

/// The segment box around [content] (a label's text or an icon).
Finder _segment(Finder content) => find.ancestor(
  of: content,
  matching: find.byWidgetPredicate(
    (w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration! as BoxDecoration).borderRadius == _radius,
  ),
);

Color? _fill(WidgetTester tester, Finder content) =>
    (tester.widget<Container>(_segment(content)).decoration! as BoxDecoration)
        .color;

Color? _iconInk(WidgetTester tester, IconData icon) =>
    tester.widget<Icon>(find.byIcon(icon)).color;

BoxDecoration _track(WidgetTester tester) =>
    tester
            .widget<Container>(
              find
                  .descendant(
                    of: find.byType(FsSegmentedControl<String>),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .decoration!
        as BoxDecoration;

bool _ring(WidgetTester tester, Finder content) => tester
    .widget<FsFocusRing>(
      find.ancestor(of: content, matching: find.byType(FsFocusRing)).first,
    )
    .visible;

const _tools = [
  FsSegment(
    value: 'select',
    icon: FsIcons.pointer,
    tooltip: 'Select',
    shortcut: SingleActivator(LogicalKeyboardKey.keyQ),
  ),
  FsSegment(value: 'move', icon: FsIcons.move, tooltip: 'Move'),
  FsSegment(value: 'rotate', icon: FsIcons.rotate, tooltip: 'Rotate'),
  FsSegment(value: 'scale', icon: FsIcons.scale, tooltip: 'Scale'),
];

const _filters = [
  FsSegment(value: 'all', label: 'All'),
  FsSegment(value: 'info', label: 'Info', count: 12),
  FsSegment(
    value: 'warnings',
    label: 'Warnings',
    count: 2,
    countKind: FsBadgeKind.warning,
  ),
  FsSegment(
    value: 'errors',
    label: 'Errors',
    count: 1,
    countKind: FsBadgeKind.error,
  ),
];

/// A control that keeps its own selection; [log] records onChanged.
Widget _live(
  List<FsSegment<String>> segments,
  String initial, {
  List<String>? log,
  bool enabled = true,
  bool trailingButton = false,
}) {
  var value = initial;
  return Padding(
    padding: const EdgeInsets.all(20),
    child: StatefulBuilder(
      builder: (context, setState) => Row(
        children: [
          FsSegmentedControl<String>(
            segments: segments,
            selected: value,
            onChanged: enabled
                ? (v) {
                    log?.add(v);
                    setState(() => value = v);
                  }
                : null,
            disabledReason: 'Nothing selected',
          ),
          if (trailingButton) FsButton(label: 'After', onPressed: () {}),
        ],
      ),
    ),
  );
}

Widget _forced(Set<WidgetState> states, String part, Widget child) =>
    FsDebugStates(states: states, part: part, child: child);

void main() {
  testWidgets('24px track, 20px segments, 22px icon segments', (tester) async {
    await pumpFs(tester, _live(_tools, 'move'));
    expect(tester.getSize(find.byType(FsSegmentedControl<String>)).height, 24);
    expect(
      tester.getSize(_segment(find.byIcon(FsIcons.rotate))),
      const Size(22, 20),
    );
    final track = _track(tester);
    expect(track.color, c.surfaceInput);
    expect((track.border! as Border).top.color, c.borderControl);
    expect(track.borderRadius, FsRadii.sm);
    // 4 × 22 + 3 gaps + 2px padding + 2px border.
    expect(tester.getSize(find.byType(FsSegmentedControl<String>)).width, 95);
  });

  testWidgets('rest text-secondary; selected accent-subtle + accent-text', (
    tester,
  ) async {
    await pumpFs(tester, _live(_tools, 'move'));
    expect(_fill(tester, find.byIcon(FsIcons.rotate)), Colors.transparent);
    expect(_iconInk(tester, FsIcons.rotate), c.textSecondary);
    expect(_fill(tester, find.byIcon(FsIcons.move)), c.accentSubtle);
    expect(_iconInk(tester, FsIcons.move), c.accentText);
  });

  testWidgets('hover and pressed on one segment (part = tooltip)', (
    tester,
  ) async {
    await pumpFs(
      tester,
      _forced({WidgetState.hovered}, 'Rotate', _live(_tools, 'move')),
    );
    expect(_fill(tester, find.byIcon(FsIcons.rotate)), c.surfaceHover);
    expect(_iconInk(tester, FsIcons.rotate), c.textPrimary);
    expect(_fill(tester, find.byIcon(FsIcons.scale)), Colors.transparent);
    await pumpFs(
      tester,
      _forced({WidgetState.pressed}, 'Rotate', _live(_tools, 'move')),
    );
    expect(_fill(tester, find.byIcon(FsIcons.rotate)), c.surfacePressed);
  });

  testWidgets('hover on the selected segment keeps accent-subtle', (
    tester,
  ) async {
    await pumpFs(
      tester,
      _forced({WidgetState.hovered}, 'Move', _live(_tools, 'move')),
    );
    expect(_fill(tester, find.byIcon(FsIcons.move)), c.accentSubtle);
  });

  testWidgets('real hover', (tester) async {
    await pumpFs(tester, _live(_filters, 'all'));
    final m = await mouse(tester);
    await hover(tester, m, find.text('Info'));
    expect(_fill(tester, find.text('Info')), c.surfaceHover);
    expect(textColor(tester, 'Info'), c.textPrimary);
  });

  testWidgets('focused (forced) draws the inset ring on that segment', (
    tester,
  ) async {
    await pumpFs(
      tester,
      _forced({WidgetState.focused}, 'Warnings', _live(_filters, 'all')),
    );
    expect(_ring(tester, find.text('Warnings')), isTrue);
    expect(_ring(tester, find.text('All')), isFalse);
  });

  testWidgets('disabled: border-subtle track, text-disabled, no fill', (
    tester,
  ) async {
    final log = <String>[];
    await pumpFs(tester, _live(_tools, 'move', log: log, enabled: false));
    expect((_track(tester).border! as Border).top.color, c.borderSubtle);
    expect(_fill(tester, find.byIcon(FsIcons.move)), Colors.transparent);
    expect(_iconInk(tester, FsIcons.move), c.textDisabled);
    expect(_iconInk(tester, FsIcons.rotate), c.textDisabled);
    expect(find.byType(Opacity), findsNothing);
    await tester.tap(find.byIcon(FsIcons.rotate));
    expect(log, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_ring(tester, find.byIcon(FsIcons.move)), isFalse);
  });

  testWidgets('a disabled segment is text-disabled and skipped', (
    tester,
  ) async {
    final log = <String>[];
    await pumpFs(
      tester,
      _live(
        [
          _tools[0],
          const FsSegment(
            value: 'move',
            icon: FsIcons.move,
            tooltip: 'Move',
            enabled: false,
          ),
          _tools[2],
        ],
        'select',
        log: log,
      ),
    );
    expect(_iconInk(tester, FsIcons.move), c.textDisabled);
    await tester.tap(find.byIcon(FsIcons.move));
    expect(log, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(log, ['rotate']);
  });

  testWidgets('a click selects; clicking the selected one does nothing', (
    tester,
  ) async {
    final log = <String>[];
    await pumpFs(tester, _live(_filters, 'all', log: log));
    await tester.tap(find.text('Errors'));
    await tester.pump();
    expect(log, ['errors']);
    expect(_fill(tester, find.text('Errors')), c.accentSubtle);
    await tester.tap(find.text('Errors'));
    expect(log, ['errors']);
  });

  testWidgets('one Tab stop: ← → move and select, ring for the keyboard', (
    tester,
  ) async {
    final log = <String>[];
    await pumpFs(
      tester,
      _live(_tools, 'move', log: log, trailingButton: true),
      width: 400,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_ring(tester, find.byIcon(FsIcons.move)), isTrue);
    expect(_ring(tester, find.byIcon(FsIcons.rotate)), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(log, ['rotate']);
    expect(_ring(tester, find.byIcon(FsIcons.rotate)), isTrue);
    expect(_ring(tester, find.byIcon(FsIcons.move)), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(log, ['rotate', 'move', 'select']);

    // At the start ← isn't handled (no wrap).
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(log, ['rotate', 'move', 'select']);

    // The next Tab leaves the control for the button after it.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_ring(tester, find.byIcon(FsIcons.pointer)), isFalse);
    expect(
      tester
          .widget<FsFocusRing>(
            find.descendant(
              of: find.byType(FsButton),
              matching: find.byType(FsFocusRing),
            ),
          )
          .visible,
      isTrue,
    );
  });

  testWidgets('right-to-left: → moves towards the start', (tester) async {
    final log = <String>[];
    await pumpFs(
      tester,
      Directionality(
        textDirection: TextDirection.rtl,
        child: _live(_tools, 'move', log: log),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(log, ['select']);
  });

  testWidgets('a mouse click never shows the ring', (tester) async {
    await pumpFs(tester, _live(_tools, 'move'));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_ring(tester, find.byIcon(FsIcons.move)), isTrue);
    await tester.tap(find.byIcon(FsIcons.scale));
    await tester.pump();
    expect(_ring(tester, find.byIcon(FsIcons.scale)), isFalse);
  });

  testWidgets('counts: plain mono text, or a badge without its icon', (
    tester,
  ) async {
    await pumpFs(tester, _live(_filters, 'all'), width: 400);
    expect(find.text('12'), findsOneWidget);
    expect(textColor(tester, '12'), c.textSecondary);
    expect(find.byType(FsBadge), findsNWidgets(2));
    expect(find.byIcon(FsIcons.alertTriangle), findsNothing);
    expect(tester.getSize(find.byType(FsBadge).first).height, 14);
    expect(textColor(tester, '2'), c.warning);
  });

  testWidgets('tooltip: name and shortcut on hover', (tester) async {
    await pumpFs(tester, _live(_tools, 'move'));
    final m = await mouse(tester);
    await hover(tester, m, find.byIcon(FsIcons.pointer));
    await tester.pump(FsTooltip.delay);
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Select'), findsOneWidget);
    expect(find.byType(FsShortcutLabel), findsOneWidget);
    await m.moveTo(const Offset(300, 500));
    await tester.pumpAndSettle();
  });

  testWidgets('semantics: selected segment, label from the tooltip', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpFs(tester, _live(_tools, 'move'));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Move').first),
      isSemantics(
        label: 'Move',
        isButton: true,
        isSelected: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });
}
