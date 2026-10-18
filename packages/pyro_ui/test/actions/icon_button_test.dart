import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../helpers.dart';

final _button = find.byType(PrIconButton);

BoxDecoration _box(WidgetTester tester) => decorationIn(tester, _button);
Color? _ink(WidgetTester tester) => tester
    .widget<Icon>(find.descendant(of: _button, matching: find.byType(Icon)))
    .color;

Widget _maybeForced(Set<WidgetState> states, Widget child) =>
    states.isEmpty ? child : PrDebugStates(states: states, child: child);

Widget _undo({
  VoidCallback? onPressed,
  bool selected = false,
  PrIconButtonSize size = PrIconButtonSize.regular,
  Set<WidgetState> forced = const {},
  String? disabledReason,
}) => Align(
  alignment: Alignment.topLeft,
  child: Padding(
    padding: const EdgeInsets.all(20),
    // The nearest PrDebugStates wins, so only add one when forcing.
    child: _maybeForced(
      forced,
      PrIconButton(
        icon: PrIcons.undo,
        tooltip: 'Undo',
        shortcut: const SingleActivator(LogicalKeyboardKey.keyZ, meta: true),
        onPressed: onPressed,
        selected: selected,
        size: size,
        disabledReason: disabledReason,
      ),
    ),
  ),
);

void main() {
  testWidgets('24 and 20px, 16px glyph', (tester) async {
    await pumpFs(tester, _undo(onPressed: () {}));
    expect(tester.getSize(_button), const Size(24, 24));
    expect(tester.widget<Icon>(find.byIcon(PrIcons.undo)).size, 16);
    await pumpFs(tester, _undo(onPressed: () {}, size: PrIconButtonSize.small));
    expect(tester.getSize(_button), const Size(20, 20));
  });

  testWidgets('rest: no fill, text-secondary', (tester) async {
    await pumpFs(tester, _undo(onPressed: () {}));
    expect(_box(tester).color, Colors.transparent);
    expect(_ink(tester), c.textSecondary);
  });

  testWidgets('hover and pressed', (tester) async {
    await pumpFs(
      tester,
      _undo(onPressed: () {}, forced: {WidgetState.hovered}),
    );
    expect(_box(tester).color, c.surfaceHover);
    expect(_ink(tester), c.textPrimary);
    await pumpFs(
      tester,
      _undo(onPressed: () {}, forced: {WidgetState.pressed}),
    );
    expect(_box(tester).color, c.surfacePressed);
  });

  testWidgets('real hover', (tester) async {
    await pumpFs(tester, _undo(onPressed: () {}));
    final m = await mouse(tester);
    await hover(tester, m, _button);
    expect(_box(tester).color, c.surfaceHover);
    await m.moveTo(const Offset(300, 500));
    await tester.pumpAndSettle();
  });

  testWidgets('selected: accent-subtle, accent-text; selected hover', (
    tester,
  ) async {
    await pumpFs(tester, _undo(onPressed: () {}, selected: true));
    expect(_box(tester).color, c.accentSubtle);
    expect(_ink(tester), c.accentText);
    await pumpFs(
      tester,
      _undo(onPressed: () {}, selected: true, forced: {WidgetState.hovered}),
    );
    expect(_box(tester).color, c.surfaceSelected);
  });

  testWidgets('disabled: no fill, text-disabled, no opacity', (tester) async {
    await pumpFs(tester, _undo(forced: {WidgetState.hovered}));
    expect(_box(tester).color, Colors.transparent);
    expect(_ink(tester), c.textDisabled);
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('focused shows the outside ring', (tester) async {
    await pumpFs(tester, _undo(onPressed: () {}));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(find.byType(PrFocusRing), findsOneWidget);
    expect(
      tester.widget<PrFocusRing>(find.byType(PrFocusRing)).visible,
      isTrue,
    );
  });

  testWidgets('click and Enter call onPressed', (tester) async {
    var presses = 0;
    await pumpFs(tester, _undo(onPressed: () => presses++));
    await tester.tap(_button);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(presses, 2);
  });

  testWidgets('tooltip: name, shortcut, and why it is disabled', (
    tester,
  ) async {
    await pumpFs(
      tester,
      PrDebugStates(
        part: 'tooltip',
        states: const {WidgetState.hovered},
        child: _undo(disabledReason: 'Nothing to undo'),
      ),
    );
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Nothing to undo'), findsOneWidget);
    expect(find.byType(PrShortcutLabel), findsOneWidget);
  });

  testWidgets('the semantics label is the tooltip', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpFs(tester, _undo(onPressed: () {}));
    expect(find.bySemanticsLabel('Undo'), findsWidgets);
    handle.dispose();
  });
}
