import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

final _log = <String>[];

FsDropAcceptance _accepts(String data) => switch (data) {
  final d when d.endsWith('.png') => FsDropAcceptance.accept,
  final d when d.endsWith('.wav') => FsDropAcceptance.reject,
  _ => FsDropAcceptance.ignore,
};

Widget _slot({
  String? fileName = 'player_run.png',
  bool missing = false,
  bool mixed = false,
  bool enabled = true,
  FsDragInFlight<String>? inFlight,
  Set<WidgetState> forced = const {},
  String? forcedPart,
}) {
  final Widget slot = FsAssetSlot<String>(
    fileName: fileName,
    placeholder: 'None (Sprite)',
    missing: missing,
    missingLabel: 'Missing',
    mixed: mixed,
    mixedLabel: '— (2 different)',
    browseTooltip: 'Browse',
    clearTooltip: 'Clear',
    onBrowse: () => _log.add('browse'),
    onClear: () => _log.add('clear'),
    onReveal: () => _log.add('reveal'),
    onOpen: () => _log.add('open'),
    willAccept: _accepts,
    onDrop: (d) => _log.add('drop $d'),
    dropHint: (d) => 'Drop $d here',
    dragInFlight: inFlight,
    enabled: enabled,
  );
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 240,
        child: forced.isEmpty
            ? slot
            : FsDebugStates(states: forced, part: forcedPart, child: slot),
      ),
      const SizedBox(height: 40),
      for (final file in ['coin.png', 'hurt.wav', 'level.json'])
        Draggable<String>(
          data: file,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: const SizedBox(width: 10, height: 10),
          child: SizedBox(height: 30, child: Text('drag $file')),
        ),
    ],
  );
}

final _box = find.byWidgetPredicate(
  (w) =>
      w is Container &&
      w.constraints?.maxHeight == FsSizes.controlSm &&
      w.decoration is BoxDecoration,
);

(Color?, Color) _look(WidgetTester tester) {
  final d = tester.widget<Container>(_box).decoration! as BoxDecoration;
  return (d.color, (d.border! as Border).top.color);
}

/// Starts dragging [file] and moves it over the slot; returns the gesture.
Future<TestGesture> _dragOver(WidgetTester tester, String file) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.text('drag $file')),
    kind: PointerDeviceKind.mouse,
  );
  await gesture.moveBy(const Offset(0, -20));
  await tester.pump();
  await gesture.moveTo(tester.getCenter(_box));
  await tester.pump();
  return gesture;
}

void main() {
  setUp(_log.clear);

  testWidgets('filled: 20px, mono name, browse and clear', (tester) async {
    await pumpFs(tester, _slot());
    expect(tester.getSize(_box).height, 20);
    expect(_look(tester), (c.surfaceInput, c.borderControl));
    final name = tester.widget<Text>(find.text('player_run.png')).style!;
    expect(name.fontFamily, contains('JetBrains Mono'));
    expect(name.color, c.textPrimary);
    expect(find.byIcon(FsIcons.folder), findsOneWidget);
    expect(find.byIcon(FsIcons.x), findsOneWidget);
    expect(find.byIcon(FsIcons.image), findsOneWidget); // no thumbnail
  });

  testWidgets('empty: placeholder, no clear', (tester) async {
    await pumpFs(tester, _slot(fileName: null));
    expect(textColor(tester, 'None (Sprite)'), c.textPlaceholder);
    expect(find.byIcon(FsIcons.x), findsNothing);
  });

  testWidgets('a thumbnail replaces the type icon', (tester) async {
    await pumpFs(
      tester,
      const SizedBox(
        width: 240,
        child: FsAssetSlot<String>(
          fileName: 'coin.png',
          placeholder: 'None',
          thumbnail: ColoredBox(key: Key('thumb'), color: Colors.amber),
        ),
      ),
    );
    expect(find.byKey(const Key('thumb')), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('thumb'))), const Size(16, 16));
    expect(find.byIcon(FsIcons.image), findsNothing);
  });

  testWidgets('hover, keyboard focus, disabled', (tester) async {
    await pumpFs(tester, _slot(forced: {WidgetState.hovered}));
    expect(_look(tester).$2, c.borderStrong);
    await pumpFs(tester, _slot(forced: {WidgetState.focused}));
    expect(_look(tester).$2, c.focusRing);
    await pumpFs(tester, _slot(enabled: false));
    expect(_look(tester), (c.surfacePanel, c.borderSubtle));
    expect(textColor(tester, 'player_run.png'), c.textDisabled);
  });

  testWidgets('missing: error fill and edge, alert icon, badge', (
    tester,
  ) async {
    await pumpFs(tester, _slot(fileName: 'hurt.wav', missing: true));
    expect(_look(tester), (c.errorSubtle, c.errorBorder));
    expect(textColor(tester, 'hurt.wav'), c.error);
    // One for the thumbnail, one in the badge.
    expect(find.byIcon(FsIcons.alertCircle), findsNWidgets(2));
    expect(find.text('Missing'), findsOneWidget);
  });

  testWidgets('mixed: the label, no clear', (tester) async {
    await pumpFs(tester, _slot(mixed: true));
    expect(textColor(tester, '— (2 different)'), c.textSecondary);
    expect(find.byIcon(FsIcons.x), findsNothing);
  });

  testWidgets('click the name to reveal, double-click to open; the '
      'placeholder browses', (tester) async {
    await pumpFs(tester, _slot());
    await tester.tap(find.text('player_run.png'));
    await tester.pump(kDoubleTapTimeout);
    expect(_log, ['reveal']);
    await tester.tap(find.text('player_run.png'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('player_run.png'));
    await tester.pumpAndSettle();
    expect(_log, ['reveal', 'open']);
    await tester.tap(find.byIcon(FsIcons.x));
    await tester.tap(find.byIcon(FsIcons.folder));
    expect(_log, ['reveal', 'open', 'clear', 'browse']);

    await pumpFs(tester, _slot(fileName: null));
    await tester.tap(find.text('None (Sprite)'));
    await tester.pump(kDoubleTapTimeout);
    expect(_log.last, 'browse');
  });

  testWidgets('keyboard: ⌫ clears, Enter browses', (tester) async {
    await pumpFs(tester, _slot());
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(_log, ['clear', 'browse']);
  });

  testWidgets('a fitting drag: drop target with the hint; dropping', (
    tester,
  ) async {
    await pumpFs(tester, _slot());
    final gesture = await _dragOver(tester, 'coin.png');
    expect(_look(tester), (c.accentSubtle, c.accentText));
    expect(textColor(tester, 'Drop coin.png here'), c.accentText);
    expect(find.byIcon(FsIcons.x), findsNothing);
    await gesture.up();
    await tester.pump();
    expect(_log, ['drop coin.png']);
    expect(_look(tester).$1, c.surfaceInput);
  });

  testWidgets('the wrong type: error edge and not-allowed cursor', (
    tester,
  ) async {
    await pumpFs(tester, _slot());
    final gesture = await _dragOver(tester, 'hurt.wav');
    expect(_look(tester), (c.surfaceInput, c.error));
    expect(
      tester
          .widgetList<MouseRegion>(
            find.descendant(
              of: find.byType(FsAssetSlot<String>),
              matching: find.byType(MouseRegion),
            ),
          )
          .map((r) => r.cursor),
      contains(SystemMouseCursors.forbidden),
    );
    await gesture.up();
    await tester.pump();
    expect(_log, isEmpty);
    expect(_look(tester).$2, isNot(c.error));
  });

  testWidgets('an ignored payload changes nothing', (tester) async {
    await pumpFs(tester, _slot());
    final gesture = await _dragOver(tester, 'level.json');
    expect(_look(tester).$2, isNot(c.error));
    expect(_look(tester).$1, c.surfaceInput);
    await gesture.up();
    await tester.pump();
    expect(_log, isEmpty);
  });

  testWidgets('a fitting drag in flight lights the slot up', (tester) async {
    final inFlight = FsDragInFlight<String>();
    addTearDown(inFlight.dispose);
    await pumpFs(tester, _slot(inFlight: inFlight));
    inFlight.value = 'coin.png';
    await tester.pump();
    expect(_look(tester), (c.accentSubtle, c.accentText));
    expect(find.text('Drop coin.png here'), findsOneWidget);
    inFlight.value = 'hurt.wav'; // the wrong type stays quiet
    await tester.pump();
    expect(_look(tester), (c.surfaceInput, c.borderControl));
    inFlight.value = null;
    await tester.pump();
    expect(find.text('player_run.png'), findsOneWidget);
  });

  testWidgets('forced drop states for the gallery', (tester) async {
    await pumpFs(
      tester,
      _slot(forced: {WidgetState.selected}, forcedPart: 'drop'),
    );
    expect(_look(tester), (c.accentSubtle, c.accentText));
    await pumpFs(
      tester,
      _slot(forced: {WidgetState.error}, forcedPart: 'drop'),
    );
    expect(_look(tester).$2, c.error);
  });

  testWidgets('disabled slots take no drops', (tester) async {
    await pumpFs(tester, _slot(enabled: false));
    final gesture = await _dragOver(tester, 'coin.png');
    expect(_look(tester).$1, c.surfacePanel);
    await gesture.up();
    await tester.pump();
    expect(_log, isEmpty);
  });
}
