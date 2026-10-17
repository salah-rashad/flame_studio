import 'dart:async';

import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

late List<String> log;

List<FsMenuEntry<String>> _entries() => [
  const FsMenuHeader('Player'),
  FsMenuItem(
    label: 'Rename',
    value: 'rename',
    shortcut: const SingleActivator(LogicalKeyboardKey.enter),
    onSelected: () => log.add('callback rename'),
  ),
  const FsMenuItem(label: 'Duplicate', icon: FsIcons.copy, value: 'duplicate'),
  const FsMenuItem(label: 'Paste as child', value: 'paste', enabled: false),
  const FsMenuSeparator(),
  const FsMenuItem(
    label: 'Add child',
    icon: FsIcons.plus,
    submenu: [
      FsMenuItem(label: 'SpriteComponent', value: 'sprite'),
      FsMenuItem(label: 'TextComponent', value: 'text'),
    ],
  ),
  const FsMenuItem(label: 'Visible', value: 'visible', checked: true),
  const FsMenuSeparator(),
  const FsMenuItem(
    label: 'Delete',
    icon: FsIcons.trash,
    value: 'delete',
    destructive: true,
  ),
];

final _panel = find.byType(FsMenuPanel<String>);

Finder _row(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(Container)).first;

Color? _fill(WidgetTester tester, String label) =>
    (tester.widget<Container>(_row(label)).decoration! as BoxDecoration).color;

Future<void> _pumpRegion(WidgetTester tester) async {
  final before = FocusNode(debugLabel: 'before');
  addTearDown(before.dispose);
  await pumpFs(
    tester,
    Column(
      children: [
        Focus(
          focusNode: before,
          autofocus: true,
          child: const SizedBox(height: 10),
        ),
        FsContextMenuRegion<String>(
          entries: _entries,
          onSelected: (v) => log.add('selected $v'),
          child: const SizedBox(key: Key('region'), width: 800, height: 400),
        ),
      ],
    ),
    width: 800,
  );
}

/// A mouse click that leaves no pointer behind, so a hovering mouse from
/// [mouse] can be added later.
Future<void> _click(
  WidgetTester tester,
  Offset at, {
  int buttons = kPrimaryButton,
}) async {
  final g = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    buttons: buttons,
  );
  await g.addPointer(location: at);
  await g.down(at);
  await g.up();
  await g.removePointer();
  await tester.pumpAndSettle();
}

Future<void> _rightClick(WidgetTester tester, Offset at) =>
    _click(tester, at, buttons: kSecondaryButton);

void main() {
  setUp(() => log = []);

  testWidgets('right click opens the menu at the pointer', (tester) async {
    await _pumpRegion(tester);
    await _rightClick(tester, const Offset(100, 120));
    expect(_panel, findsOneWidget);
    expect(tester.getTopLeft(_panel), const Offset(100, 120));
    expect(tester.getSize(_panel).width, 248);
  });

  testWidgets('the box: overlay surface, border, radius-md, popover shadow', (
    tester,
  ) async {
    await _pumpRegion(tester);
    await _rightClick(tester, const Offset(100, 120));
    final d = decorationIn(tester, _panel);
    expect(d.color, c.surfaceOverlay);
    expect((d.border! as Border).top.color, c.borderOverlay);
    expect(d.borderRadius, FsRadii.md);
    expect(d.boxShadow, FsShadows.dark.popover);
    expect(tester.getSize(_row('Rename')).height, 24);
    expect(textColor(tester, 'Player'), c.textSecondary);
    expect(find.byType(FsShortcutLabel), findsOneWidget);
  });

  testWidgets('a click chooses: menu closes, then the callbacks run', (
    tester,
  ) async {
    await _pumpRegion(tester);
    await _rightClick(tester, const Offset(100, 120));
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);
    expect(log, ['callback rename', 'selected rename']);
  });

  testWidgets('a click outside or Esc closes without a choice', (tester) async {
    await _pumpRegion(tester);
    await _rightClick(tester, const Offset(100, 120));
    await _click(tester, const Offset(700, 380));
    expect(_panel, findsNothing);

    await _rightClick(tester, const Offset(100, 120));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);
    expect(log, isEmpty);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'before');
  });

  testWidgets('hover highlights in accent and moves focus', (tester) async {
    await _pumpRegion(tester);
    await _rightClick(tester, const Offset(100, 120));
    final m = await mouse(tester);
    await hover(tester, m, find.text('Duplicate'));
    expect(_fill(tester, 'Duplicate'), c.accent);
    expect(textColor(tester, 'Duplicate'), c.textOnAccent);
    expect(
      tester.widget<Icon>(find.byIcon(FsIcons.copy)).color,
      c.textOnAccent,
    );
    await hover(tester, m, find.text('Rename'));
    expect(_fill(tester, 'Duplicate'), Colors.transparent);
    expect(_fill(tester, 'Rename'), c.accent);
    await m.moveTo(const Offset(700, 380));
    await tester.pumpAndSettle();
  });

  testWidgets('disabled: text-disabled, no highlight, no choice', (
    tester,
  ) async {
    await _pumpRegion(tester);
    await _rightClick(tester, const Offset(100, 120));
    expect(textColor(tester, 'Paste as child'), c.textDisabled);
    final m = await mouse(tester);
    await hover(tester, m, find.text('Paste as child'));
    expect(_fill(tester, 'Paste as child'), Colors.transparent);
    await tester.tap(find.text('Paste as child'));
    await tester.pumpAndSettle();
    expect(_panel, findsOneWidget);
    expect(log, isEmpty);
    await m.moveTo(const Offset(700, 380));
    await tester.pumpAndSettle();
  });

  testWidgets('destructive: error; highlighted on error-border', (
    tester,
  ) async {
    await _pumpRegion(tester);
    await _rightClick(tester, const Offset(100, 120));
    expect(textColor(tester, 'Delete'), c.error);
    expect(tester.widget<Icon>(find.byIcon(FsIcons.trash)).color, c.error);
    final m = await mouse(tester);
    await hover(tester, m, find.text('Delete'));
    expect(_fill(tester, 'Delete'), c.errorBorder);
    expect(textColor(tester, 'Delete'), c.textPrimary);
    await m.moveTo(const Offset(700, 380));
    await tester.pumpAndSettle();
  });

  testWidgets('checked items show an accent-text check', (tester) async {
    await _pumpRegion(tester);
    await _rightClick(tester, const Offset(100, 120));
    final check = find.descendant(
      of: _row('Visible'),
      matching: find.byIcon(FsIcons.check),
    );
    expect(tester.widget<Icon>(check).color, c.accentText);
  });

  testWidgets('keyboard: ↓ skips the header and disabled items, wraps; Enter', (
    tester,
  ) async {
    await _pumpRegion(tester);
    await _rightClick(tester, const Offset(100, 120));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_fill(tester, 'Rename'), c.accent);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_fill(tester, 'Add child'), c.accent); // skipped Paste as child
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(_fill(tester, 'Delete'), c.errorBorder); // wrapped; destructive
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(log, ['selected delete']);
  });

  testWidgets('submenu: → opens it beside its parent, ← closes it', (
    tester,
  ) async {
    await _pumpRegion(tester);
    await _rightClick(tester, const Offset(100, 120));
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(_panel, findsNWidgets(2));
    // Beside the parent item, first item level with it.
    final parent = tester.getRect(_row('Add child'));
    final sprite = tester.getRect(_row('SpriteComponent'));
    expect(sprite.left, greaterThan(parent.right));
    expect(sprite.top, parent.top);
    // Focus went to the first item; the parent keeps surface-pressed.
    expect(_fill(tester, 'SpriteComponent'), c.accent);
    expect(_fill(tester, 'Add child'), c.surfacePressed);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(_panel, findsOneWidget);
    expect(_fill(tester, 'Add child'), c.accent);
  });

  testWidgets('submenu: opens after 150ms of hover; choosing closes all', (
    tester,
  ) async {
    await _pumpRegion(tester);
    await _rightClick(tester, const Offset(100, 120));
    final m = await mouse(tester);
    await hover(tester, m, find.text('Add child'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('SpriteComponent'), findsNothing);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();
    expect(find.text('SpriteComponent'), findsOneWidget);
    await tester.tap(find.text('TextComponent'));
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);
    expect(log, ['selected text']);
  });

  testWidgets('Esc in a submenu closes one level', (tester) async {
    await _pumpRegion(tester);
    await _rightClick(tester, const Offset(100, 120));
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_panel, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);
  });

  testWidgets('near the right edge the menu opens to the left', (tester) async {
    await _pumpRegion(tester);
    await _rightClick(tester, const Offset(700, 120));
    expect(tester.getTopRight(_panel).dx, 700);
  });

  testWidgets('FsMenuButton opens below its trigger', (tester) async {
    await pumpFs(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: FsMenuButton<String>(
            entries: _entries(),
            onSelected: (v) => log.add(v),
            builder: (context, controller) => FsIconButton(
              icon: FsIcons.more,
              tooltip: 'More',
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(FsIconButton));
    await tester.pumpAndSettle();
    final trigger = tester.getRect(find.byType(FsIconButton));
    expect(tester.getTopLeft(_panel), Offset(trigger.left, trigger.bottom + 4));
    await tester.tap(find.byType(FsIconButton));
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);
  });

  testWidgets('showFsContextMenu completes with the choice or null', (
    tester,
  ) async {
    late BuildContext ctx;
    await pumpFs(
      tester,
      Builder(
        builder: (context) {
          ctx = context;
          return const SizedBox(height: 400);
        },
      ),
      width: 800,
    );
    String? chosen = 'pending';
    unawaited(
      showFsContextMenu<String>(
        ctx,
        position: const Offset(50, 60),
        entries: _entries(),
        header: 'Hero',
      ).then((v) => chosen = v),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(_panel), const Offset(50, 60));
    expect(find.text('Hero'), findsOneWidget);
    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();
    expect(chosen, 'duplicate');
    expect(_panel, findsNothing);

    String? none = 'pending';
    unawaited(
      showFsContextMenu<String>(
        ctx,
        position: const Offset(50, 60),
        entries: _entries(),
      ).then((v) => none = v),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(none, isNull);
  });

  testWidgets('a standalone panel reports choices directly', (tester) async {
    await pumpFs(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: FsMenuPanel<String>(
          entries: _entries(),
          onSelected: (v) => log.add(v),
        ),
      ),
    );
    await tester.tap(find.text('Duplicate'));
    expect(log, ['duplicate']);
  });

  testWidgets('forced item states by label (gallery)', (tester) async {
    await pumpFs(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: FsDebugStates(
          part: 'Duplicate',
          states: const {WidgetState.pressed},
          child: FsDebugStates(
            part: 'Add child',
            states: const {WidgetState.selected},
            child: FsMenuPanel<String>(entries: _entries()),
          ),
        ),
      ),
    );
    expect(_fill(tester, 'Duplicate'), c.accentPressed);
    expect(_fill(tester, 'Add child'), c.surfacePressed);
  });
}
