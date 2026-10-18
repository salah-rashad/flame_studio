import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../helpers.dart';

final _log = <String>[];

Widget _slot({
  String? name = 'Camera',
  bool picking = false,
  bool missing = false,
  bool mixed = false,
  bool enabled = true,
}) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    SizedBox(
      width: 240,
      child: PrEntitySlot<String>(
        name: name,
        placeholder: 'None (CameraComponent)',
        typeIcon: PrIcons.video,
        missing: missing,
        missingLabel: 'Missing',
        mixed: mixed,
        mixedLabel: '— (3 different)',
        picking: picking,
        pickingHint: 'Click a node…',
        pickTooltip: 'Pick in scene',
        clearTooltip: 'Clear',
        onPick: () => _log.add('pick'),
        onCancelPick: () => _log.add('cancel'),
        onClear: () => _log.add('clear'),
        onReveal: () => _log.add('reveal'),
        willAccept: (d) => d.startsWith('Camera')
            ? PrDropAcceptance.accept
            : PrDropAcceptance.reject,
        onDrop: (d) => _log.add('drop $d'),
        dropHint: (d) => 'Drop $d here',
        enabled: enabled,
      ),
    ),
    const SizedBox(height: 40),
    const Draggable<String>(
      data: 'Camera2',
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: SizedBox(width: 10, height: 10),
      child: SizedBox(height: 30, child: Text('drag node')),
    ),
  ],
);

final _box = find.byWidgetPredicate(
  (w) =>
      w is Container &&
      w.constraints?.maxHeight == PrSizes.controlSm &&
      w.decoration is BoxDecoration,
);

(Color?, Color) _look(WidgetTester tester) {
  final d = tester.widget<Container>(_box).decoration! as BoxDecoration;
  return (d.color, (d.border! as Border).top.color);
}

/// The fill behind the crosshair.
Color? _crosshairFill(WidgetTester tester) {
  final box = tester.widget<Container>(
    find
        .ancestor(
          of: find.byIcon(PrIcons.crosshair),
          matching: find.byType(Container),
        )
        .first,
  );
  return (box.decoration! as BoxDecoration).color;
}

void main() {
  setUp(_log.clear);

  testWidgets('filled: type icon, name in the UI font, pick and clear', (
    tester,
  ) async {
    await pumpFs(tester, _slot());
    expect(find.byIcon(PrIcons.video), findsOneWidget);
    expect(tester.widget<Icon>(find.byIcon(PrIcons.video)).size, 14);
    final name = tester.widget<Text>(find.text('Camera')).style!;
    expect(name.fontFamily, contains('Inter'));
    expect(name.color, c.textPrimary);
    expect(find.byIcon(PrIcons.crosshair), findsOneWidget);
    expect(find.byIcon(PrIcons.x), findsOneWidget);
  });

  testWidgets('empty: the link icon and the placeholder', (tester) async {
    await pumpFs(tester, _slot(name: null));
    expect(find.byIcon(PrIcons.link), findsOneWidget);
    expect(textColor(tester, 'None (CameraComponent)'), c.textPlaceholder);
    expect(find.byIcon(PrIcons.x), findsNothing);
  });

  testWidgets('picking: latched crosshair, accent edge and hint', (
    tester,
  ) async {
    await pumpFs(tester, _slot(name: null, picking: true));
    expect(_look(tester).$2, c.accentText);
    expect(textColor(tester, 'Click a node…'), c.accentText);
    expect(_crosshairFill(tester), c.accentSubtle);
    // The crosshair again cancels.
    await tester.tap(find.byIcon(PrIcons.crosshair));
    expect(_log, ['cancel']);
  });

  testWidgets('crosshair, Enter and the placeholder start picking', (
    tester,
  ) async {
    await pumpFs(tester, _slot(name: null));
    expect(_crosshairFill(tester), Colors.transparent);
    await tester.tap(find.byIcon(PrIcons.crosshair));
    await tester.tap(find.text('None (CameraComponent)'));
    await tester.pump(kDoubleTapTimeout);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(_log, ['pick', 'pick', 'pick']);
  });

  testWidgets('Esc cancels picking while focused', (tester) async {
    await pumpFs(tester, _slot(picking: true));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(_log, ['cancel']);
  });

  testWidgets('click the name to reveal; ⌫ clears', (tester) async {
    await pumpFs(tester, _slot());
    await tester.tap(find.text('Camera'));
    await tester.pump(kDoubleTapTimeout);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    expect(_log, ['reveal', 'clear']);
  });

  testWidgets('missing: the old name in error and the badge', (tester) async {
    await pumpFs(tester, _slot(name: 'Enemy#42', missing: true));
    expect(_look(tester), (c.errorSubtle, c.errorBorder));
    expect(textColor(tester, 'Enemy#42'), c.error);
    expect(find.text('Missing'), findsOneWidget);
  });

  testWidgets('mixed and disabled', (tester) async {
    await pumpFs(tester, _slot(mixed: true));
    expect(textColor(tester, '— (3 different)'), c.textSecondary);
    await pumpFs(tester, _slot(enabled: false));
    expect(_look(tester), (c.surfacePanel, c.borderSubtle));
    await tester.tap(find.byIcon(PrIcons.crosshair));
    expect(_log, isEmpty);
  });

  testWidgets('a node dragged from the tree drops in', (tester) async {
    await pumpFs(tester, _slot(name: null));
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('drag node')),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(_box));
    await tester.pump();
    expect(_look(tester), (c.accentSubtle, c.accentText));
    expect(find.text('Drop Camera2 here'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(_log, ['drop Camera2']);
  });
}
