import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../helpers.dart';

late List<String> log;

final _menu = <PrMenuEntry<String>>[
  const PrMenuItem(
    label: 'Play in window',
    value: 'window',
    checked: true,
    shortcut: SingleActivator(LogicalKeyboardKey.keyR, meta: true),
  ),
  const PrMenuItem(label: 'Play on device…', value: 'device'),
  const PrMenuSeparator(),
  const PrMenuItem(label: 'Profile mode', icon: PrIcons.zap, value: 'profile'),
];

final _panel = find.byType(PrMenuPanel<String>);

Finder _box(Finder content) => find.ancestor(
  of: content,
  matching: find.byWidgetPredicate(
    (w) => w is Container && w.decoration is BoxDecoration,
  ),
);

BoxDecoration _mainBox(WidgetTester tester) =>
    tester.widget<Container>(_box(find.text('Play')).first).decoration!
        as BoxDecoration;

BoxDecoration _caretBox(WidgetTester tester) =>
    tester
            .widget<Container>(_box(find.byIcon(PrIcons.chevronDown)).first)
            .decoration!
        as BoxDecoration;

Color _divider(WidgetTester tester) => tester
    .widget<ColoredBox>(
      find.descendant(
        of: find.byType(PrSplitButton<String>),
        matching: find.byType(ColoredBox),
      ),
    )
    .color;

Color _edge(BoxDecoration d) => (d.border! as Border).top.color;

Widget _split({
  PrButtonVariant variant = PrButtonVariant.primary,
  bool enabled = true,
  Set<WidgetState> forced = const {},
  String? part,
}) {
  Widget split = PrSplitButton<String>(
    label: 'Play',
    leading: const PrPlayGlyph(size: 14),
    onPressed: enabled ? () => log.add('main') : null,
    menuItems: _menu,
    onSelected: (v) => log.add(v),
    variant: variant,
    tooltip: 'Play',
    menuTooltip: 'Play options',
    disabledReason: 'No scene open',
  );
  if (forced.isNotEmpty) {
    split = PrDebugStates(states: forced, part: part, child: split);
  }
  return Align(
    alignment: Alignment.topLeft,
    child: Padding(padding: const EdgeInsets.all(20), child: split),
  );
}

/// A mouse click that leaves no pointer behind.
Future<void> _click(WidgetTester tester, Offset at) async {
  final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await g.addPointer(location: at);
  await g.down(at);
  await g.up();
  await g.removePointer();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => log = []);

  testWidgets('24px; the caret is 20px with its divider', (tester) async {
    await pumpFs(tester, _split());
    expect(tester.getSize(find.byType(PrSplitButton<String>)).height, 24);
    final caret = tester.getSize(_box(find.byIcon(PrIcons.chevronDown)).first);
    expect(caret, const Size(19, 24));
    expect(tester.widget<Icon>(find.byIcon(PrIcons.chevronDown)).size, 14);
    expect(
      IconTheme.of(tester.element(find.byType(PrPlayGlyph))).color,
      c.textOnAccent,
    );
  });

  testWidgets('primary rest: accent parts, accent-pressed divider', (
    tester,
  ) async {
    await pumpFs(tester, _split());
    expect(_mainBox(tester).color, c.accent);
    expect(_caretBox(tester).color, c.accent);
    expect(_divider(tester), c.accentPressed);
    expect(textColor(tester, 'Play'), c.textOnAccent);
  });

  testWidgets('hover main and hover caret are independent', (tester) async {
    await pumpFs(tester, _split(forced: {WidgetState.hovered}));
    expect(_mainBox(tester).color, c.accentHover);
    expect(_caretBox(tester).color, c.accent);
    await pumpFs(tester, _split(forced: {WidgetState.hovered}, part: 'caret'));
    expect(_mainBox(tester).color, c.accent);
    expect(_caretBox(tester).color, c.accentHover);
  });

  testWidgets('real hover reaches only the part under the mouse', (
    tester,
  ) async {
    await pumpFs(tester, _split());
    final m = await mouse(tester);
    await hover(tester, m, find.byIcon(PrIcons.chevronDown));
    expect(_caretBox(tester).color, c.accentHover);
    expect(_mainBox(tester).color, c.accent);
    await hover(tester, m, find.text('Play'));
    expect(_caretBox(tester).color, c.accent);
    expect(_mainBox(tester).color, c.accentHover);
    await m.moveTo(const Offset(300, 500));
    await tester.pumpAndSettle();
  });

  testWidgets('pressed main; open caret', (tester) async {
    await pumpFs(tester, _split(forced: {WidgetState.pressed}));
    expect(_mainBox(tester).color, c.accentPressed);
    await pumpFs(tester, _split(forced: {WidgetState.selected}, part: 'open'));
    expect(_caretBox(tester).color, c.accentPressed);
    expect(_mainBox(tester).color, c.accent);
  });

  testWidgets('focused: the ring goes around the main part', (tester) async {
    await pumpFs(tester, _split(forced: {WidgetState.focused}));
    expect(
      tester.widget<PrFocusRing>(find.byType(PrFocusRing)).visible,
      isTrue,
    );
    expect(
      find.descendant(
        of: find.byType(PrFocusRing),
        matching: find.byIcon(PrIcons.chevronDown),
      ),
      findsNothing,
    );
  });

  testWidgets('secondary: raised parts, border-control divider and edges', (
    tester,
  ) async {
    await pumpFs(tester, _split(variant: PrButtonVariant.secondary));
    expect(_mainBox(tester).color, c.surfaceRaised);
    expect(_edge(_mainBox(tester)), c.borderControl);
    expect(_divider(tester), c.borderControl);
    expect(textColor(tester, 'Play'), c.textPrimary);
    await pumpFs(
      tester,
      _split(variant: PrButtonVariant.secondary, forced: {WidgetState.hovered}),
    );
    expect(_mainBox(tester).color, c.surfaceHover);
    expect(_edge(_mainBox(tester)), c.borderStrong);
    expect(_edge(_caretBox(tester)), c.borderControl);
    await pumpFs(
      tester,
      _split(
        variant: PrButtonVariant.secondary,
        forced: {WidgetState.selected},
        part: 'open',
      ),
    );
    expect(_caretBox(tester).color, c.surfacePressed);
  });

  testWidgets('disabled: both parts raised, border-subtle, text-disabled', (
    tester,
  ) async {
    await pumpFs(tester, _split(enabled: false));
    for (final d in [_mainBox(tester), _caretBox(tester)]) {
      expect(d.color, c.surfaceRaised);
      expect(_edge(d), c.borderSubtle);
    }
    expect(_divider(tester), c.borderSubtle);
    expect(textColor(tester, 'Play'), c.textDisabled);
    expect(find.byType(Opacity), findsNothing);
    await _click(tester, tester.getCenter(find.byIcon(PrIcons.chevronDown)));
    await _click(tester, tester.getCenter(find.text('Play')));
    expect(_panel, findsNothing);
    expect(log, isEmpty);
  });

  testWidgets('a click on the main part runs it; the caret opens the menu', (
    tester,
  ) async {
    await pumpFs(tester, _split());
    await _click(tester, tester.getCenter(find.text('Play')));
    expect(log, ['main']);
    expect(_panel, findsNothing);

    await _click(tester, tester.getCenter(find.byIcon(PrIcons.chevronDown)));
    expect(_panel, findsOneWidget);
    expect(_caretBox(tester).color, c.accentPressed);
    // Below the button, left aligned.
    final button = tester.getRect(find.byType(PrSplitButton<String>));
    expect(
      tester.getTopLeft(_panel),
      Offset(button.left, button.bottom + PrSpacing.s1),
    );

    await _click(tester, tester.getCenter(find.text('Play on device…')));
    expect(log, ['main', 'device']);
    expect(_panel, findsNothing);
    expect(_caretBox(tester).color, c.accent);
  });

  testWidgets('a second caret click closes the menu', (tester) async {
    await pumpFs(tester, _split());
    final caret = tester.getCenter(find.byIcon(PrIcons.chevronDown));
    await _click(tester, caret);
    expect(_panel, findsOneWidget);
    await _click(tester, caret);
    expect(_panel, findsNothing);
    expect(log, isEmpty);
  });

  testWidgets('keyboard: Enter runs the main action, ↓ and Alt+↓ open', (
    tester,
  ) async {
    await pumpFs(tester, _split());
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      tester.widget<PrFocusRing>(find.byType(PrFocusRing)).visible,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(log, ['main', 'main']);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_panel, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
    expect(_panel, findsOneWidget);

    // The menu has focus: ↓ moves to the first item, Enter chooses it.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(log, ['main', 'main', 'window']);
    expect(_panel, findsNothing);
  });

  testWidgets('tooltips: main with the reason while disabled; caret', (
    tester,
  ) async {
    await pumpFs(
      tester,
      PrDebugStates(
        part: 'tooltip',
        states: const {WidgetState.hovered},
        child: _split(enabled: false),
      ),
    );
    expect(find.text('No scene open'), findsNWidgets(2));
    expect(find.text('Play options'), findsOneWidget);
  });

  testWidgets('semantics: main label and caret label', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpFs(tester, _split());
    expect(find.bySemanticsLabel('Play'), findsWidgets);
    expect(find.bySemanticsLabel('Play options'), findsWidgets);
    handle.dispose();
  });
}
