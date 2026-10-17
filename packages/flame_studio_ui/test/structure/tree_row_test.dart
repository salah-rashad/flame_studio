import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flame_studio_ui/src/foundation/focus_ring.dart';
import 'package:flame_studio_ui/src/structure/tree_row.dart' show FsDropPainter;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

final _row = find.byType(FsTreeRow<String>);

Color? _fill(WidgetTester tester, [Finder? of]) =>
    decorationIn(tester, of ?? _row).color;

FsDropPainter? _drop(WidgetTester tester, Finder of) => tester
    .widgetList<CustomPaint>(
      find.descendant(of: of, matching: find.byType(CustomPaint)),
    )
    .map((p) => p.foregroundPainter)
    .whereType<FsDropPainter>()
    .firstOrNull;

FsTreeRow<String> _player({
  bool selected = false,
  bool keyboardCursor = false,
  FsTreeRowTone tone = FsTreeRowTone.normal,
  List<FsTreeRowAction> actions = const [],
  VoidCallback? onTap,
  VoidCallback? onDoubleTap,
  ValueChanged<Offset>? onSecondaryTap,
  ValueChanged<bool>? onExpandedChanged,
  int depth = 1,
}) => FsTreeRow<String>(
  depth: depth,
  name: 'Player',
  icon: FsIcons.image,
  hasChildren: true,
  selected: selected,
  keyboardCursor: keyboardCursor,
  tone: tone,
  actions: actions,
  onTap: onTap,
  onDoubleTap: onDoubleTap,
  onSecondaryTap: onSecondaryTap,
  onExpandedChanged: onExpandedChanged,
);

void main() {
  group('layout and colours', () {
    testWidgets('22px; 16px indent per level + 4; inset 4px', (tester) async {
      await pumpFs(tester, _player(depth: 2));
      expect(tester.getSize(_row).height, FsSizes.rowTree);
      // 4 inset + (2 × 16 + 4) indent + 16 chevron + 4 gap.
      expect(tester.getTopLeft(find.byIcon(FsIcons.image)).dx, 4 + 36 + 16 + 4);
    });

    testWidgets('default: primary name, secondary icon, no fill', (
      tester,
    ) async {
      await pumpFs(tester, _player());
      expect(textColor(tester, 'Player'), c.textPrimary);
      expect(
        tester.widget<Icon>(find.byIcon(FsIcons.image)).color,
        c.textSecondary,
      );
      expect(_fill(tester), isNull);
    });

    testWidgets('hover fills and shows the actions; pinned ones always', (
      tester,
    ) async {
      await pumpFs(
        tester,
        _player(
          actions: [
            FsTreeRowAction(
              icon: FsIcons.eye,
              tooltip: 'Hide',
              onPressed: () {},
            ),
            FsTreeRowAction(
              icon: FsIcons.lock,
              tooltip: 'Unlock',
              onPressed: () {},
              pinned: true,
            ),
          ],
        ),
      );
      bool visible(IconData icon) => tester
          .widget<Visibility>(
            find.ancestor(
              of: find.byIcon(icon),
              matching: find.byType(Visibility),
            ),
          )
          .visible;
      expect(visible(FsIcons.eye), isFalse);
      expect(visible(FsIcons.lock), isTrue);
      final m = await mouse(tester);
      await hover(tester, m, find.text('Player'));
      expect(_fill(tester), c.surfaceHover);
      expect(visible(FsIcons.eye), isTrue);
    });

    testWidgets('pressed', (tester) async {
      await pumpFs(tester, _player(onTap: () {}));
      final g = await tester.startGesture(
        tester.getCenter(find.text('Player')),
      );
      await tester.pump();
      expect(_fill(tester), c.surfacePressed);
      await g.up();
    });

    testWidgets('selected: surface-selected while the panel has focus', (
      tester,
    ) async {
      await pumpFs(tester, _player(selected: true));
      expect(_fill(tester), c.surfaceSelected);
      expect(
        tester.widget<Icon>(find.byIcon(FsIcons.image)).color,
        c.textPrimary,
      );
    });

    testWidgets('selected in an unfocused panel: surface-selected-inactive', (
      tester,
    ) async {
      await pumpFs(tester, FsPanelFocus(child: _player(selected: true)));
      expect(_fill(tester), c.surfaceSelectedInactive);
    });

    testWidgets('tones', (tester) async {
      await pumpFs(tester, _player(tone: FsTreeRowTone.dimmed));
      expect(textColor(tester, 'Player'), c.textDisabled);
      expect(
        tester.widget<Icon>(find.byIcon(FsIcons.image)).color,
        c.textDisabled,
      );
      await pumpFs(tester, _player(tone: FsTreeRowTone.prefab));
      expect(textColor(tester, 'Player'), c.prefab);
      expect(tester.widget<Icon>(find.byIcon(FsIcons.image)).color, c.prefab);
      await pumpFs(tester, _player(tone: FsTreeRowTone.error));
      expect(textColor(tester, 'Player'), c.error);
    });

    testWidgets('keyboard cursor: inset ring only after keyboard input', (
      tester,
    ) async {
      bool ring() => tester
          .widgetList<CustomPaint>(
            find.descendant(of: _row, matching: find.byType(CustomPaint)),
          )
          .map((p) => p.foregroundPainter)
          .whereType<FsEdgePainter>()
          .any((p) => !p.outside);
      await pumpFs(tester, _player(keyboardCursor: true, onTap: () {}));
      await tester.tap(find.text('Player'));
      await tester.pump();
      expect(ring(), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(ring(), isTrue);
    });

    testWidgets('forced focus draws the ring (gallery)', (tester) async {
      await pumpFs(
        tester,
        FsDebugStates(states: const {WidgetState.focused}, child: _player()),
      );
      expect(hasPainter<FsEdgePainter>(tester, _row), isTrue);
    });
  });

  group('input', () {
    testWidgets('click calls onTap; the chevron toggles without it', (
      tester,
    ) async {
      var taps = 0;
      final expanded = <bool>[];
      await pumpFs(
        tester,
        _player(onTap: () => taps++, onExpandedChanged: expanded.add),
      );
      await tester.tap(find.text('Player'));
      expect(taps, 1);
      await tester.tap(find.byIcon(FsIcons.chevronRight));
      expect(expanded, [true]);
      expect(taps, 1);
    });

    testWidgets('an action press does not select the row', (tester) async {
      var taps = 0;
      var hides = 0;
      await pumpFs(
        tester,
        _player(
          onTap: () => taps++,
          actions: [
            FsTreeRowAction(
              icon: FsIcons.eye,
              tooltip: 'Hide',
              onPressed: () => hides++,
              pinned: true,
            ),
          ],
        ),
      );
      await tester.tap(find.byIcon(FsIcons.eye));
      expect(hides, 1);
      expect(taps, 0);
    });

    testWidgets('double click and right click', (tester) async {
      var doubles = 0;
      Offset? menuAt;
      await pumpFs(
        tester,
        _player(
          onTap: () {},
          onDoubleTap: () => doubles++,
          onSecondaryTap: (p) => menuAt = p,
        ),
      );
      final center = tester.getCenter(find.text('Player'));
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(center);
      await tester.pumpAndSettle();
      expect(doubles, 1);
      await tester.tapAt(center, buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(menuAt, center);
    });
  });

  group('rename', () {
    Widget renaming(List<String> log) => FsTreeRow<String>(
      depth: 0,
      name: 'Player',
      renaming: true,
      onRenameCommit: (name) => log.add('commit $name'),
      onRenameCancel: () => log.add('cancel'),
    );

    testWidgets('shows the field with the whole name selected', (tester) async {
      await pumpFs(tester, renaming([]));
      await tester.pump();
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.controller.text, 'Player');
      expect(
        field.controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 6),
      );
      expect(field.focusNode.hasFocus, isTrue);
      expect(
        tester.getSize(find.byType(EditableText)).height,
        lessThanOrEqualTo(20),
      );
    });

    testWidgets('Enter commits', (tester) async {
      final log = <String>[];
      await pumpFs(tester, renaming(log));
      await tester.pump();
      await tester.enterText(find.byType(EditableText), 'Hero');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(log, ['commit Hero']);
    });

    testWidgets('Esc cancels, once', (tester) async {
      final log = <String>[];
      await pumpFs(tester, renaming(log));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await pumpFs(tester, const FsTreeRow<String>(depth: 0, name: 'Player'));
      expect(log, ['cancel']);
    });

    testWidgets('clicking elsewhere commits', (tester) async {
      final log = <String>[];
      await pumpFs(tester, renaming(log));
      await tester.pump();
      await tester.tapAt(const Offset(200, 500), kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(log, ['commit Player']);
    });
  });

  group('drag and drop', () {
    late List<String> log;
    late List<String> drags;
    setUp(() {
      log = [];
      drags = [];
    });

    Widget tree({
      bool canHaveChildren = true,
      bool Function(String, FsDropZone)? canAccept,
      VoidCallback? onAutoExpand,
    }) => Column(
      children: [
        FsTreeRow<String>(
          depth: 0,
          name: 'Camera',
          dragData: 'camera',
          onDragStarted: () => drags.add('started'),
          onDragEnded: () => drags.add('ended'),
        ),
        const SizedBox(height: 40),
        FsTreeRow<String>(
          key: const Key('target'),
          depth: 0,
          name: 'Player',
          hasChildren: canHaveChildren,
          canHaveChildren: canHaveChildren,
          canAccept: canAccept,
          onAccept: (data, zone) => log.add('$data ${zone.name}'),
          onAutoExpand: onAutoExpand,
        ),
      ],
    );

    final target = find.byKey(const Key('target'));

    Future<TestGesture> dragTo(WidgetTester tester, double fraction) async {
      final g = await tester.startGesture(
        tester.getCenter(find.text('Camera')),
        kind: PointerDeviceKind.mouse,
      );
      await g.moveBy(const Offset(0, 10));
      await tester.pump();
      final rect = tester.getRect(target);
      await g.moveTo(Offset(rect.center.dx, rect.top + rect.height * fraction));
      await tester.pump();
      return g;
    }

    testWidgets('drag feedback text gets a style, not the debug underline', (
      tester,
    ) async {
      await pumpFs(
        tester,
        FsTreeRow<String>(
          depth: 0,
          name: 'Camera',
          dragData: 'camera',
          dragFeedback: () => const Text('feedback', key: Key('fb')),
        ),
      );
      final g = await tester.startGesture(
        tester.getCenter(find.text('Camera')),
        kind: PointerDeviceKind.mouse,
      );
      await g.moveBy(const Offset(0, 20));
      await tester.pump();
      final style = DefaultTextStyle.of(
        tester.element(find.byKey(const Key('fb'))),
      ).style;
      expect(style.decoration, isNot(TextDecoration.underline));
      expect(style.fontFamily, contains('Inter'));
      await g.up();
      await tester.pump();
    });

    for (final (fraction, zone) in const [
      (0.1, FsDropZone.above),
      (0.5, FsDropZone.inside),
      (0.9, FsDropZone.below),
    ]) {
      testWidgets(
        'zones 25/50/25: ${(fraction * 100).round()}% is ${zone.name}',
        (tester) async {
          await pumpFs(tester, tree());
          final g = await dragTo(tester, fraction);
          final painter = _drop(tester, target)!;
          expect(painter.zone, zone);
          expect(painter.accepted, isTrue);
          if (zone == FsDropZone.inside) {
            expect(_fill(tester, target), c.accentSubtle);
          }
          await g.up();
          await tester.pump();
          expect(log, ['camera ${zone.name}']);
          expect(_drop(tester, target), isNull);
        },
      );
    }

    testWidgets('a drag reports its start and end', (tester) async {
      await pumpFs(tester, tree());
      final g = await dragTo(tester, 0.5);
      expect(drags, ['started']);
      await g.up();
      await tester.pump();
      expect(drags, ['started', 'ended']);
    });

    testWidgets('leaf rows: 50/50 above/below', (tester) async {
      await pumpFs(tester, tree(canHaveChildren: false));
      var g = await dragTo(tester, 0.4);
      expect(_drop(tester, target)!.zone, FsDropZone.above);
      await g.up();
      await tester.pump();
      g = await dragTo(tester, 0.6);
      expect(_drop(tester, target)!.zone, FsDropZone.below);
      await g.up();
      await tester.pump();
      expect(log, ['camera above', 'camera below']);
    });

    testWidgets('rejected: error border, not-allowed cursor, no drop', (
      tester,
    ) async {
      await pumpFs(
        tester,
        tree(canAccept: (data, zone) => zone != FsDropZone.inside),
      );
      final g = await dragTo(tester, 0.5);
      final painter = _drop(tester, target)!;
      expect(painter.accepted, isFalse);
      expect(_fill(tester, target), isNot(c.accentSubtle));
      final cursors = tester
          .widgetList<MouseRegion>(
            find.descendant(of: target, matching: find.byType(MouseRegion)),
          )
          .map((r) => r.cursor);
      expect(cursors, contains(SystemMouseCursors.forbidden));
      await g.up();
      await tester.pump();
      expect(log, isEmpty);
    });

    testWidgets('auto-expands after 600ms inside', (tester) async {
      var expands = 0;
      await pumpFs(tester, tree(onAutoExpand: () => expands++));
      final g = await dragTo(tester, 0.5);
      await tester.pump(const Duration(milliseconds: 500));
      expect(expands, 0);
      await tester.pump(const Duration(milliseconds: 150));
      expect(expands, 1);
      await g.up();
      await tester.pump();
    });

    testWidgets('leaving "inside" cancels the auto-expand', (tester) async {
      var expands = 0;
      await pumpFs(tester, tree(onAutoExpand: () => expands++));
      final g = await dragTo(tester, 0.5);
      await tester.pump(const Duration(milliseconds: 300));
      final rect = tester.getRect(target);
      await g.moveTo(Offset(rect.center.dx, rect.top + 2));
      await tester.pump(const Duration(milliseconds: 600));
      expect(expands, 0);
      await g.up();
      await tester.pump();
    });

    testWidgets('forced drop states for the gallery', (tester) async {
      await pumpFs(
        tester,
        const FsDebugStates(
          part: 'drop-below',
          states: {WidgetState.hovered},
          child: FsTreeRow<String>(depth: 0, name: 'Player'),
        ),
      );
      expect(_drop(tester, _row)!.zone, FsDropZone.below);
      await pumpFs(
        tester,
        const FsDebugStates(
          part: 'drop-inside',
          states: {WidgetState.error},
          child: FsTreeRow<String>(depth: 0, name: 'Player'),
        ),
      );
      expect(_drop(tester, _row)!.accepted, isFalse);
      // A global forced hover is not a drop.
      await pumpFs(
        tester,
        const FsDebugStates(
          states: {WidgetState.hovered},
          child: FsTreeRow<String>(depth: 0, name: 'Player'),
        ),
      );
      expect(_drop(tester, _row), isNull);
    });
  });
}
