import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_ui/pyro_ui.dart';
import 'package:pyro_ui/src/foundation/focus_ring.dart';

import '../helpers.dart';

late List<String> log;
late Map<String, FocusNode> nodes;

FocusNode _n(String name) => nodes[name] ??= FocusNode(debugLabel: name);

String? _focused() {
  final primary = FocusManager.instance.primaryFocus;
  for (final MapEntry(:key, :value) in nodes.entries) {
    if (value == primary) return key;
  }
  return null;
}

final _toolbar = find.byType(PrToolbar);

Widget _icon(String name, IconData icon, {bool enabled = true}) => PrIconButton(
  icon: icon,
  tooltip: name,
  focusNode: _n(name),
  onPressed: enabled ? () => log.add(name) : null,
);

Widget _harness({
  PrToolbarStyle style = PrToolbarStyle.main,
  bool highlighted = false,
  bool textField = false,
}) {
  var tool = 'select';
  return Column(
    children: [
      PrButton(label: 'Before', onPressed: () {}, focusNode: _n('before')),
      StatefulBuilder(
        builder: (context, setState) => PrToolbar(
          style: style,
          highlighted: highlighted,
          leading: [
            PrToolbarGroup(
              children: [
                _icon('undo', PrIcons.undo),
                _icon('redo', PrIcons.redo, enabled: false),
              ],
            ),
            PrToolbarGroup(
              children: [
                PrSegmentedControl<String>(
                  focusNode: _n('tools'),
                  segments: const [
                    PrSegment(value: 'select', icon: PrIcons.pointer),
                    PrSegment(value: 'move', icon: PrIcons.move),
                  ],
                  selected: tool,
                  onChanged: (v) => setState(() {
                    tool = v;
                    log.add(v);
                  }),
                ),
              ],
            ),
          ],
          center: [
            PrToolbarGroup(
              children: [
                PrSplitButton<String>(
                  label: 'Play',
                  focusNode: _n('play'),
                  onPressed: () => log.add('play'),
                  menuItems: const [],
                ),
                _icon('stop', PrIcons.stop, enabled: false),
              ],
            ),
          ],
          trailing: [
            if (textField)
              PrToolbarGroup(
                children: [
                  SizedBox(
                    width: 120,
                    child: PrTextField(value: 'abc', focusNode: _n('field')),
                  ),
                ],
              ),
            PrToolbarGroup(
              children: [
                _icon('search', PrIcons.search),
                _icon('settings', PrIcons.sliders),
              ],
            ),
          ],
        ),
      ),
      PrButton(label: 'After', onPressed: () {}, focusNode: _n('after')),
    ],
  );
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() {
    log = [];
    nodes = {};
  });
  tearDown(() {
    for (final n in nodes.values) {
      n.dispose();
    }
  });

  testWidgets('32px; main: surface-raised with a bg-app bottom edge', (
    tester,
  ) async {
    await pumpFs(tester, _harness(), width: 800);
    expect(tester.getSize(_toolbar), const Size(800, 32));
    final d = decorationIn(tester, _toolbar);
    expect(d.color, c.surfaceRaised);
    expect((d.border! as Border).bottom.color, c.bgApp);
  });

  testWidgets('viewport: surface-panel with a border-subtle bottom edge', (
    tester,
  ) async {
    await pumpFs(tester, _harness(style: PrToolbarStyle.viewport), width: 800);
    final d = decorationIn(tester, _toolbar);
    expect(d.color, c.surfacePanel);
    expect((d.border! as Border).bottom.color, c.borderSubtle);
  });

  testWidgets('2px inside a group; 1×16 dividers between groups', (
    tester,
  ) async {
    await pumpFs(tester, _harness(), width: 800);
    final undo = tester.getRect(find.byIcon(PrIcons.undo).first);
    final redo = tester.getRect(find.byIcon(PrIcons.redo).first);
    // Icons are centred in 24px buttons.
    expect(redo.center.dx - undo.center.dx, 24 + 2);
    expect(tester.getTopLeft(find.byType(PrIconButton).first).dx, 4);

    final dividers = find.descendant(
      of: _toolbar,
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints ==
                const BoxConstraints.tightFor(width: 1, height: 16),
      ),
    );
    // One between the two leading groups; none next to the spacers.
    expect(dividers, findsOneWidget);
    expect(
      tester
          .widget<ColoredBox>(
            find.descendant(of: dividers, matching: find.byType(ColoredBox)),
          )
          .color,
      c.borderSubtle,
    );
    final groups = find.byType(PrToolbarGroup);
    final first = tester.getRect(groups.first);
    final divider = tester.getRect(
      find.descendant(of: dividers, matching: find.byType(ColoredBox)),
    );
    final second = tester.getRect(groups.at(1));
    expect(divider.left - first.right, 8);
    expect(second.left - divider.right, 8);
  });

  testWidgets('center sits midway between leading and trailing', (
    tester,
  ) async {
    await pumpFs(tester, _harness(), width: 800);
    final groups = find.byType(PrToolbarGroup);
    final leadingEnd = tester.getRect(groups.at(1)).right;
    final center = tester.getRect(groups.at(2));
    final trailingStart = tester.getRect(groups.at(3)).left;
    expect(
      center.left - leadingEnd,
      moreOrLessEquals(trailingStart - center.right, epsilon: 1),
    );
  });

  testWidgets('highlighted draws the accent outline', (tester) async {
    await pumpFs(tester, _harness(), width: 800);
    expect(hasPainter<PrEdgePainter>(tester, _toolbar), isFalse);
    await pumpFs(tester, _harness(highlighted: true), width: 800);
    final paint = tester
        .widgetList<CustomPaint>(
          find.descendant(of: _toolbar, matching: find.byType(CustomPaint)),
        )
        .map((p) => p.foregroundPainter)
        .whereType<PrEdgePainter>()
        .first;
    expect(paint.color, c.accent);
    expect(paint.width, 1);
    expect(paint.outside, isFalse);
  });

  testWidgets('roving focus: one Tab stop, ← → and Home/End inside', (
    tester,
  ) async {
    await pumpFs(tester, _harness(), width: 800);
    _n('before').requestFocus();
    await tester.pump();

    await _key(tester, LogicalKeyboardKey.tab);
    expect(_focused(), 'undo');
    expect(
      tester
          .widget<PrFocusRing>(
            find.ancestor(
              of: find.byIcon(PrIcons.undo),
              matching: find.byType(PrFocusRing),
            ),
          )
          .visible,
      isTrue,
    );

    // Redo is disabled: skipped.
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused(), 'tools');

    // The segmented control keeps → until its last segment.
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused(), 'tools');
    expect(log, ['move']);
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused(), 'play');

    // Stop is disabled; → goes on to the trailing group.
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused(), 'search');
    await _key(tester, LogicalKeyboardKey.end);
    expect(_focused(), 'settings');
    // No wrap at the end.
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused(), 'settings');
    await _key(tester, LogicalKeyboardKey.home);
    expect(_focused(), 'undo');
    // Move is already the last segment, so → passes straight through.
    await _key(tester, LogicalKeyboardKey.arrowRight);
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused(), 'play');

    // Enter still reaches the control.
    await _key(tester, LogicalKeyboardKey.enter);
    expect(log, ['move', 'play']);

    // Tab leaves the toolbar, from wherever focus is.
    await _key(tester, LogicalKeyboardKey.tab);
    expect(_focused(), 'after');

    // Shift+Tab comes back to the control that last had focus.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await _key(tester, LogicalKeyboardKey.tab);
    expect(_focused(), 'play');
    await _key(tester, LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(_focused(), 'before');
  });

  testWidgets('a text field keeps ← →', (tester) async {
    await pumpFs(tester, _harness(textField: true), width: 800);
    _n('field').requestFocus();
    await tester.pump();
    await _key(tester, LogicalKeyboardKey.arrowLeft);
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused(), 'field');
    // Tab still leaves the toolbar.
    await _key(tester, LogicalKeyboardKey.tab);
    expect(_focused(), 'after');
  });

  testWidgets('a click on a control focuses nothing new', (tester) async {
    await pumpFs(tester, _harness(), width: 800);
    _n('before').requestFocus();
    await tester.pump();
    await tester.tap(find.byIcon(PrIcons.search));
    await tester.pump();
    expect(log, ['search']);
    expect(_focused(), 'before');
  });
}
