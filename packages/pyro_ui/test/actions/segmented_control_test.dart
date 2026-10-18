import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_ui/pyro_ui.dart';

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
                    of: find.byType(PrSegmentedControl<String>),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .decoration!
        as BoxDecoration;

bool _ring(WidgetTester tester, Finder content) => tester
    .widget<PrFocusRing>(
      find.ancestor(of: content, matching: find.byType(PrFocusRing)).first,
    )
    .visible;

const _tools = [
  PrSegment(
    value: 'select',
    icon: PrIcons.pointer,
    tooltip: 'Select',
    shortcut: SingleActivator(LogicalKeyboardKey.keyQ),
  ),
  PrSegment(value: 'move', icon: PrIcons.move, tooltip: 'Move'),
  PrSegment(value: 'rotate', icon: PrIcons.rotate, tooltip: 'Rotate'),
  PrSegment(value: 'scale', icon: PrIcons.scale, tooltip: 'Scale'),
];

const _filters = [
  PrSegment(value: 'all', label: 'All'),
  PrSegment(value: 'info', label: 'Info', count: 12),
  PrSegment(
    value: 'warnings',
    label: 'Warnings',
    count: 2,
    countKind: PrBadgeKind.warning,
  ),
  PrSegment(
    value: 'errors',
    label: 'Errors',
    count: 1,
    countKind: PrBadgeKind.error,
  ),
];

/// A control that keeps its own selection; [log] records onChanged.
Widget _live(
  List<PrSegment<String>> segments,
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
          PrSegmentedControl<String>(
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
          if (trailingButton) PrButton(label: 'After', onPressed: () {}),
        ],
      ),
    ),
  );
}

Widget _forced(Set<WidgetState> states, String part, Widget child) =>
    PrDebugStates(states: states, part: part, child: child);

void main() {
  testWidgets('24px track, 20px segments, 22px icon segments', (tester) async {
    await pumpFs(tester, _live(_tools, 'move'));
    expect(tester.getSize(find.byType(PrSegmentedControl<String>)).height, 24);
    expect(
      tester.getSize(_segment(find.byIcon(PrIcons.rotate))),
      const Size(22, 20),
    );
    final track = _track(tester);
    expect(track.color, c.surfaceInput);
    expect((track.border! as Border).top.color, c.borderControl);
    expect(track.borderRadius, PrRadii.sm);
    // 4 × 22 + 3 gaps + 2px padding + 2px border.
    expect(tester.getSize(find.byType(PrSegmentedControl<String>)).width, 95);
  });

  testWidgets('rest text-secondary; selected accent-subtle + accent-text', (
    tester,
  ) async {
    await pumpFs(tester, _live(_tools, 'move'));
    expect(_fill(tester, find.byIcon(PrIcons.rotate)), Colors.transparent);
    expect(_iconInk(tester, PrIcons.rotate), c.textSecondary);
    expect(_fill(tester, find.byIcon(PrIcons.move)), c.accentSubtle);
    expect(_iconInk(tester, PrIcons.move), c.accentText);
  });

  testWidgets('hover and pressed on one segment (part = tooltip)', (
    tester,
  ) async {
    await pumpFs(
      tester,
      _forced({WidgetState.hovered}, 'Rotate', _live(_tools, 'move')),
    );
    expect(_fill(tester, find.byIcon(PrIcons.rotate)), c.surfaceHover);
    expect(_iconInk(tester, PrIcons.rotate), c.textPrimary);
    expect(_fill(tester, find.byIcon(PrIcons.scale)), Colors.transparent);
    await pumpFs(
      tester,
      _forced({WidgetState.pressed}, 'Rotate', _live(_tools, 'move')),
    );
    expect(_fill(tester, find.byIcon(PrIcons.rotate)), c.surfacePressed);
  });

  testWidgets('hover on the selected segment keeps accent-subtle', (
    tester,
  ) async {
    await pumpFs(
      tester,
      _forced({WidgetState.hovered}, 'Move', _live(_tools, 'move')),
    );
    expect(_fill(tester, find.byIcon(PrIcons.move)), c.accentSubtle);
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
    expect(_fill(tester, find.byIcon(PrIcons.move)), Colors.transparent);
    expect(_iconInk(tester, PrIcons.move), c.textDisabled);
    expect(_iconInk(tester, PrIcons.rotate), c.textDisabled);
    expect(find.byType(Opacity), findsNothing);
    await tester.tap(find.byIcon(PrIcons.rotate));
    expect(log, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_ring(tester, find.byIcon(PrIcons.move)), isFalse);
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
          const PrSegment(
            value: 'move',
            icon: PrIcons.move,
            tooltip: 'Move',
            enabled: false,
          ),
          _tools[2],
        ],
        'select',
        log: log,
      ),
    );
    expect(_iconInk(tester, PrIcons.move), c.textDisabled);
    await tester.tap(find.byIcon(PrIcons.move));
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
    expect(_ring(tester, find.byIcon(PrIcons.move)), isTrue);
    expect(_ring(tester, find.byIcon(PrIcons.rotate)), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(log, ['rotate']);
    expect(_ring(tester, find.byIcon(PrIcons.rotate)), isTrue);
    expect(_ring(tester, find.byIcon(PrIcons.move)), isFalse);

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
    expect(_ring(tester, find.byIcon(PrIcons.pointer)), isFalse);
    expect(
      tester
          .widget<PrFocusRing>(
            find.descendant(
              of: find.byType(PrButton),
              matching: find.byType(PrFocusRing),
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
    expect(_ring(tester, find.byIcon(PrIcons.move)), isTrue);
    await tester.tap(find.byIcon(PrIcons.scale));
    await tester.pump();
    expect(_ring(tester, find.byIcon(PrIcons.scale)), isFalse);
  });

  testWidgets('counts: plain mono text, or a badge without its icon', (
    tester,
  ) async {
    await pumpFs(tester, _live(_filters, 'all'), width: 400);
    expect(find.text('12'), findsOneWidget);
    expect(textColor(tester, '12'), c.textSecondary);
    expect(find.byType(PrBadge), findsNWidgets(2));
    expect(find.byIcon(PrIcons.alertTriangle), findsNothing);
    expect(tester.getSize(find.byType(PrBadge).first).height, 14);
    expect(textColor(tester, '2'), c.warning);
  });

  testWidgets('tooltip: name and shortcut on hover', (tester) async {
    await pumpFs(tester, _live(_tools, 'move'));
    final m = await mouse(tester);
    await hover(tester, m, find.byIcon(PrIcons.pointer));
    await tester.pump(PrTooltip.delay);
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Select'), findsOneWidget);
    expect(find.byType(PrShortcutLabel), findsOneWidget);
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
