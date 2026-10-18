import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_ui/pyro_ui.dart';
import 'package:pyro_ui/src/foundation/focus_ring.dart';

import '../helpers.dart';

/// The tab's box: the Container with the top-edge foreground decoration.
Finder _tab(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate(
    (w) => w is Container && w.foregroundDecoration != null,
  ),
);

Color? _fill(WidgetTester tester, String label) =>
    (tester.widget<Container>(_tab(label)).decoration! as BoxDecoration).color;

BorderSide _topEdge(WidgetTester tester, String label) =>
    ((tester.widget<Container>(_tab(label)).foregroundDecoration!
                    as BoxDecoration)
                .border!
            as Border)
        .top;

Finder _close(String label) =>
    find.descendant(of: _tab(label), matching: find.byIcon(PrIcons.x));

bool _closeVisible(WidgetTester tester, String label) => tester
    .widget<Visibility>(
      find.ancestor(of: _close(label), matching: find.byType(Visibility)).first,
    )
    .visible;

Finder _dot(String label) => find.descendant(
  of: _tab(label),
  matching: find.byWidgetPredicate(
    (w) =>
        w is Container &&
        w.constraints == const BoxConstraints.tightFor(width: 8, height: 8),
  ),
);

bool _dotVisible(WidgetTester tester, String label) => tester
    .widget<Visibility>(
      find.ancestor(of: _dot(label), matching: find.byType(Visibility)).first,
    )
    .visible;

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

const _docs = [
  PrTab(value: 'level', label: 'level_1.scene', icon: PrIcons.file),
  PrTab(
    value: 'menu',
    label: 'main_menu.scene',
    icon: PrIcons.file,
    dirty: true,
  ),
  PrTab(value: 'player', label: 'player.prefab', icon: PrIcons.box),
];

class _Harness extends StatefulWidget {
  const _Harness({
    this.tabs = _docs,
    this.style = PrTabsStyle.document,
    this.log,
    this.closable = true,
  });

  final List<PrTab<String>> tabs;
  final PrTabsStyle style;
  final List<String>? log;
  final bool closable;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late String selected = widget.tabs.first.value;

  @override
  Widget build(BuildContext context) => PrTabs<String>(
    tabs: widget.tabs,
    selected: selected,
    style: widget.style,
    closeTooltip: 'Close',
    onSelect: (v) {
      widget.log?.add('select $v');
      setState(() => selected = v);
    },
    onClose: widget.closable ? (v) => widget.log?.add('close $v') : null,
  );
}

void main() {
  group('look', () {
    testWidgets('28px strip on bg-app; 12px left padding; 1px gaps', (
      tester,
    ) async {
      await pumpFs(tester, const _Harness(), width: 600);
      final strip = find.byType(PrTabs<String>);
      expect(tester.getSize(strip).height, 28);
      expect(decorationIn(tester, strip).color, c.bgApp);
      // 27px tabs above the 1px bg-app bottom line.
      expect(tester.getSize(_tab('level_1.scene')).height, 27);
      expect(tester.getTopLeft(find.byIcon(PrIcons.file).first).dx, 12);
      final level = tester.widget<Container>(_tab('level_1.scene'));
      final border =
          (level.decoration! as BoxDecoration).border! as BorderDirectional;
      expect(border.end, BorderSide(color: c.bgApp));
    });

    testWidgets('rest: raised, secondary body text', (tester) async {
      await pumpFs(tester, const _Harness(), width: 600);
      expect(_fill(tester, 'player.prefab'), c.surfaceRaised);
      expect(textColor(tester, 'player.prefab'), c.textSecondary);
      expect(
        tester.widget<Text>(find.text('player.prefab')).style!.fontWeight,
        PrText.body.fontWeight,
      );
      expect(_topEdge(tester, 'player.prefab'), BorderSide.none);
    });

    testWidgets('selected: panel fill, primary 500, accent-text top edge', (
      tester,
    ) async {
      await pumpFs(tester, const _Harness(), width: 600);
      expect(_fill(tester, 'level_1.scene'), c.surfacePanel);
      expect(textColor(tester, 'level_1.scene'), c.textPrimary);
      expect(
        tester.widget<Text>(find.text('level_1.scene')).style!.fontWeight,
        PrText.bodyStrong.fontWeight,
      );
      expect(
        _topEdge(tester, 'level_1.scene'),
        BorderSide(color: c.accentText, width: 2),
      );
    });

    testWidgets('selected in an unfocused panel: text-secondary top edge', (
      tester,
    ) async {
      final node = FocusScopeNode();
      addTearDown(node.dispose);
      await pumpFs(
        tester,
        PrPanelFocus(node: node, child: const _Harness()),
        width: 600,
      );
      expect(_topEdge(tester, 'level_1.scene').color, c.textSecondary);
      node.requestFocus();
      await tester.pump();
      expect(_topEdge(tester, 'level_1.scene').color, c.accentText);
    });

    testWidgets('hover, pressed; selected keeps its fill', (tester) async {
      await pumpFs(
        tester,
        const PrDebugStates(states: {WidgetState.hovered}, child: _Harness()),
        width: 600,
      );
      expect(_fill(tester, 'player.prefab'), c.surfaceHover);
      expect(textColor(tester, 'player.prefab'), c.textPrimary);
      expect(_fill(tester, 'level_1.scene'), c.surfacePanel);
      await pumpFs(
        tester,
        const PrDebugStates(states: {WidgetState.pressed}, child: _Harness()),
        width: 600,
      );
      expect(_fill(tester, 'player.prefab'), c.surfacePressed);
      expect(_fill(tester, 'level_1.scene'), c.surfacePanel);
    });

    testWidgets('a tab label as the part forces that tab only', (tester) async {
      await pumpFs(
        tester,
        const PrDebugStates(
          states: {WidgetState.hovered},
          part: 'main_menu.scene',
          child: _Harness(),
        ),
        width: 600,
      );
      expect(_fill(tester, 'main_menu.scene'), c.surfaceHover);
      expect(_closeVisible(tester, 'main_menu.scene'), isTrue);
      expect(_fill(tester, 'player.prefab'), c.surfaceRaised);
    });

    testWidgets('keyboard focus: inset ring', (tester) async {
      await pumpFs(tester, const _Harness(), width: 600);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final ring = tester.widget<PrFocusRing>(
        find.ancestor(
          of: _tab('level_1.scene'),
          matching: find.byType(PrFocusRing),
        ),
      );
      expect(ring.visible, isTrue);
      expect(
        hasPainter<PrEdgePainter>(tester, find.byType(PrTabs<String>)),
        isTrue,
      );
    });

    testWidgets('disabled: text-disabled on raised, clicks ignored', (
      tester,
    ) async {
      final log = <String>[];
      await pumpFs(
        tester,
        _Harness(
          log: log,
          tabs: const [
            PrTab(value: 'a', label: 'A'),
            PrTab(value: 'b', label: 'B', enabled: false),
          ],
        ),
        width: 600,
      );
      expect(textColor(tester, 'B'), c.textDisabled);
      expect(_fill(tester, 'B'), c.surfaceRaised);
      await _click(tester, tester.getCenter(find.text('B')));
      expect(log, isEmpty);
    });

    testWidgets('error: label and icon in error', (tester) async {
      await pumpFs(
        tester,
        const _Harness(
          tabs: [
            PrTab(value: 'a', label: 'A'),
            PrTab(
              value: 'c',
              label: 'Console',
              icon: PrIcons.terminal,
              error: true,
            ),
          ],
        ),
        width: 600,
      );
      expect(textColor(tester, 'Console'), c.error);
      expect(tester.widget<Icon>(find.byIcon(PrIcons.terminal)).color, c.error);
    });

    testWidgets('badges after the label, 6px from it', (tester) async {
      await pumpFs(
        tester,
        const _Harness(
          style: PrTabsStyle.dock,
          tabs: [
            PrTab(
              value: 'console',
              label: 'Console',
              badges: [
                PrBadge(kind: PrBadgeKind.warning, count: 2),
                PrBadge(kind: PrBadgeKind.error, count: 1),
              ],
            ),
          ],
        ),
        width: 600,
      );
      final badges = find.byType(PrBadge);
      expect(badges, findsNWidgets(2));
      expect(
        tester.getTopLeft(badges.first).dx -
            tester.getTopRight(find.text('Console')).dx,
        6,
      );
      expect(
        tester.getTopLeft(badges.last).dx - tester.getTopRight(badges.first).dx,
        4,
      );
    });
  });

  group('closing', () {
    testWidgets('× shows on the selected tab and on hover only', (
      tester,
    ) async {
      await pumpFs(tester, const _Harness(), width: 600);
      expect(_closeVisible(tester, 'level_1.scene'), isTrue);
      expect(_closeVisible(tester, 'player.prefab'), isFalse);
      final m = await mouse(tester);
      await hover(tester, m, find.text('player.prefab'));
      expect(_closeVisible(tester, 'player.prefab'), isTrue);
    });

    testWidgets('dirty: a dot that becomes × on hover', (tester) async {
      await pumpFs(tester, const _Harness(), width: 600);
      expect(_dotVisible(tester, 'main_menu.scene'), isTrue);
      expect(_closeVisible(tester, 'main_menu.scene'), isFalse);
      final dot = tester.widget<Container>(_dot('main_menu.scene'));
      expect((dot.decoration! as BoxDecoration).color, c.textSecondary);
      final m = await mouse(tester);
      await hover(tester, m, find.text('main_menu.scene'));
      expect(_dotVisible(tester, 'main_menu.scene'), isFalse);
      expect(_closeVisible(tester, 'main_menu.scene'), isTrue);
    });

    testWidgets('clicking × closes without selecting', (tester) async {
      final log = <String>[];
      await pumpFs(tester, _Harness(log: log), width: 600);
      await _click(tester, tester.getCenter(_close('level_1.scene')));
      expect(log, ['close level']);
    });

    testWidgets('× hover: surface-pressed and text-primary', (tester) async {
      await pumpFs(
        tester,
        const PrDebugStates(
          states: {WidgetState.hovered},
          part: 'close',
          child: _Harness(),
        ),
        width: 600,
      );
      expect(tester.widget<Icon>(_close('level_1.scene')).color, c.textPrimary);
      // Unparted forced states don't reach ×.
      await pumpFs(
        tester,
        const PrDebugStates(states: {WidgetState.hovered}, child: _Harness()),
        width: 600,
      );
      expect(
        tester.widget<Icon>(_close('level_1.scene')).color,
        c.textSecondary,
      );
    });

    testWidgets('middle click closes', (tester) async {
      final log = <String>[];
      await pumpFs(tester, _Harness(log: log), width: 600);
      await _click(
        tester,
        tester.getCenter(find.text('player.prefab')),
        buttons: kMiddleMouseButton,
      );
      expect(log, ['close player']);
    });

    testWidgets('⌘W / Ctrl+W closes the selected tab while focused', (
      tester,
    ) async {
      final log = <String>[];
      await pumpFs(tester, _Harness(log: log), width: 600);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      final mac = defaultTargetPlatform == TargetPlatform.macOS;
      final modifier = mac
          ? LogicalKeyboardKey.metaLeft
          : LogicalKeyboardKey.controlLeft;
      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.sendKeyUpEvent(modifier);
      expect(log, ['close level']);
    });

    testWidgets('no × or close without onClose, or for unclosable tabs', (
      tester,
    ) async {
      final log = <String>[];
      await pumpFs(tester, _Harness(log: log, closable: false), width: 600);
      expect(_close('level_1.scene'), findsNothing);
      expect(_close('player.prefab'), findsNothing);
      // The dirty dot stays and never turns into ×.
      expect(_dotVisible(tester, 'main_menu.scene'), isTrue);
      await _click(
        tester,
        tester.getCenter(find.text('player.prefab')),
        buttons: kMiddleMouseButton,
      );
      expect(log, isEmpty);
      final m = await mouse(tester);
      await hover(tester, m, find.text('main_menu.scene'));
      expect(_dotVisible(tester, 'main_menu.scene'), isTrue);
      expect(_closeVisible(tester, 'main_menu.scene'), isFalse);

      await pumpFs(
        tester,
        const _Harness(
          tabs: [PrTab(value: 'a', label: 'A', closable: false)],
        ),
        width: 600,
      );
      expect(find.byIcon(PrIcons.x), findsNothing);
      // 12px right padding without the × slot.
      expect(
        tester.getTopRight(_tab('A')).dx -
            tester.getTopRight(find.text('A')).dx,
        12 + 1,
      );
    });

    testWidgets('dock style: never closable', (tester) async {
      await pumpFs(tester, const _Harness(style: PrTabsStyle.dock), width: 600);
      expect(_close('level_1.scene'), findsNothing);
      expect(_close('player.prefab'), findsNothing);
      expect(_closeVisible(tester, 'main_menu.scene'), isFalse);
    });
  });

  group('selecting', () {
    testWidgets('click selects', (tester) async {
      final log = <String>[];
      await pumpFs(tester, _Harness(log: log), width: 600);
      await _click(tester, tester.getCenter(find.text('player.prefab')));
      expect(log, ['select player']);
      expect(_fill(tester, 'player.prefab'), c.surfacePanel);
    });

    testWidgets('Enter and Space select the focused tab', (tester) async {
      final log = <String>[];
      await pumpFs(tester, _Harness(log: log), width: 600);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(log, ['select menu', 'select player']);
    });
  });
}
