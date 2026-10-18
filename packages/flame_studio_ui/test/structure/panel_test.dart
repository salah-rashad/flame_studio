import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

final _header = find.byWidgetPredicate(
  (w) => w is Container && w.foregroundDecoration != null,
);

BorderSide _topEdge(WidgetTester tester) =>
    ((tester.widget<Container>(_header).foregroundDecoration! as BoxDecoration)
                .border!
            as Border)
        .top;

Future<void> _click(WidgetTester tester, Offset at) async {
  final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await g.addPointer(location: at);
  await g.down(at);
  await g.up();
  await g.removePointer();
  await tester.pumpAndSettle();
}

Widget _panel({
  List<Widget> actions = const [],
  List<FsMenuEntry<void>> overflow = const [],
  Widget? headerProgress,
  FocusScopeNode? focusNode,
  Widget body = const SizedBox.expand(),
}) => SizedBox(
  height: 200,
  child: FsPanel(
    title: 'Scene',
    icon: FsIcons.listTree,
    actions: actions,
    overflow: overflow,
    overflowTooltip: 'More',
    headerProgress: headerProgress,
    focusNode: focusNode,
    body: body,
  ),
);

void main() {
  testWidgets('28px raised header with a bg-app bottom edge; panel body', (
    tester,
  ) async {
    await pumpFs(tester, _panel());
    expect(tester.getSize(_header).height, 28);
    final decoration = decorationIn(tester, find.byType(FsPanel));
    expect(decoration.color, c.surfaceRaised);
    expect((decoration.border! as Border).bottom.color, c.bgApp);
    expect(
      tester
          .widget<ColoredBox>(
            find
                .descendant(
                  of: find.byType(FsPanel),
                  matching: find.byType(ColoredBox),
                )
                .first,
          )
          .color,
      c.surfacePanel,
    );
    final title = tester.widget<Text>(find.text('Scene'));
    expect(title.style!.fontSize, FsText.heading.fontSize);
    expect(title.style!.fontWeight, FsText.heading.fontWeight);
    expect(tester.getSize(find.byIcon(FsIcons.listTree)), const Size(16, 16));
  });

  testWidgets('unfocused: secondary title and icon, no top edge', (
    tester,
  ) async {
    await pumpFs(tester, _panel());
    expect(textColor(tester, 'Scene'), c.textSecondary);
    expect(
      tester.widget<Icon>(find.byIcon(FsIcons.listTree)).color,
      c.textSecondary,
    );
    expect(_topEdge(tester), BorderSide.none);
  });

  testWidgets('focus inside: primary title and a 2px accent-text top edge', (
    tester,
  ) async {
    final inner = FocusNode();
    addTearDown(inner.dispose);
    await pumpFs(
      tester,
      _panel(
        body: Focus(focusNode: inner, child: const SizedBox()),
      ),
    );
    inner.requestFocus();
    await tester.pump();
    expect(textColor(tester, 'Scene'), c.textPrimary);
    expect(_topEdge(tester), BorderSide(color: c.accentText, width: 2));
  });

  testWidgets('rows inside read the panel focus', (tester) async {
    final node = FocusScopeNode();
    addTearDown(node.dispose);
    await pumpFs(
      tester,
      _panel(
        focusNode: node,
        body: const FsTreeRow<String>(depth: 0, name: 'Player', selected: true),
      ),
    );
    expect(
      decorationIn(tester, find.byType(FsTreeRow<String>)).color,
      c.surfaceSelectedInactive,
    );
    node.requestFocus();
    await tester.pump();
    expect(
      decorationIn(tester, find.byType(FsTreeRow<String>)).color,
      c.surfaceSelected,
    );
  });

  testWidgets('a click anywhere in the panel focuses it', (tester) async {
    await pumpFs(tester, _panel());
    await _click(tester, tester.getCenter(find.byType(FsPanel)));
    expect(textColor(tester, 'Scene'), c.textPrimary);
  });

  testWidgets('the app focuses the panel through its focusNode', (
    tester,
  ) async {
    final node = FocusScopeNode();
    addTearDown(node.dispose);
    await pumpFs(tester, _panel(focusNode: node));
    node.requestFocus();
    await tester.pump();
    expect(textColor(tester, 'Scene'), c.textPrimary);
    node.unfocus();
    // Leaving a scope settles one frame later.
    await tester.pump();
    await tester.pump();
    expect(textColor(tester, 'Scene'), c.textSecondary);
  });

  testWidgets('forced part "panel" draws it focused', (tester) async {
    await pumpFs(
      tester,
      FsDebugStates(
        states: const {WidgetState.focused},
        part: 'panel',
        child: _panel(),
      ),
    );
    expect(textColor(tester, 'Scene'), c.textPrimary);
    expect(_topEdge(tester).color, c.accentText);
  });

  testWidgets('actions sit at the end of the header, 4px apart', (
    tester,
  ) async {
    await pumpFs(
      tester,
      _panel(
        actions: [
          FsIconButton(
            icon: FsIcons.plus,
            tooltip: 'Add',
            size: FsIconButtonSize.small,
            onPressed: () {},
          ),
          FsIconButton(
            icon: FsIcons.filter,
            tooltip: 'Filter',
            size: FsIconButtonSize.small,
            onPressed: () {},
          ),
        ],
      ),
    );
    final add = tester.getRect(find.byType(FsIconButton).first);
    final filter = tester.getRect(find.byType(FsIconButton).last);
    expect(filter.right, 360 - 4);
    expect(filter.left - add.right, 4);
    expect(add.size, const Size(20, 20));
    expect(add.center.dy, closeTo(13.5, 0.01)); // centred above the 1px edge
  });

  test('more than 3 actions asserts', () {
    expect(
      () => FsPanel(
        title: 'x',
        actions: const [SizedBox(), SizedBox(), SizedBox(), SizedBox()],
        body: const SizedBox(),
      ),
      throwsAssertionError,
    );
  });

  testWidgets('the ⋯ button opens the overflow menu', (tester) async {
    var chose = 0;
    await pumpFs(
      tester,
      _panel(
        overflow: [
          FsMenuItem(label: 'Collapse all', onSelected: () => chose++),
        ],
      ),
    );
    expect(find.byIcon(FsIcons.more), findsOneWidget);
    await _click(tester, tester.getCenter(find.byIcon(FsIcons.more)));
    expect(find.text('Collapse all'), findsOneWidget);
    // Latched while open.
    expect(
      tester.widget<FsIconButton>(find.byType(FsIconButton)).selected,
      isTrue,
    );
    await _click(tester, tester.getCenter(find.text('Collapse all')));
    expect(chose, 1);
    expect(find.text('Collapse all'), findsNothing);
  });

  testWidgets('no ⋯ button without overflow entries', (tester) async {
    await pumpFs(tester, _panel());
    expect(find.byIcon(FsIcons.more), findsNothing);
  });

  testWidgets('forced part "overflow" reaches only the ⋯ button', (
    tester,
  ) async {
    await pumpFs(
      tester,
      FsDebugStates(
        states: const {WidgetState.hovered},
        part: 'overflow',
        child: _panel(
          actions: [
            FsIconButton(
              icon: FsIcons.lock,
              tooltip: 'Lock',
              size: FsIconButtonSize.small,
              onPressed: () {},
            ),
          ],
          overflow: [FsMenuItem(label: 'Reset', onSelected: () {})],
        ),
      ),
    );
    Color? fill(IconData icon) => decorationIn(
      tester,
      find.ancestor(of: find.byIcon(icon), matching: find.byType(FsIconButton)),
    ).color;
    expect(fill(FsIcons.more), c.surfaceHover);
    expect(fill(FsIcons.lock), Colors.transparent);
  });

  testWidgets('headerProgress sits right under the header, over the body', (
    tester,
  ) async {
    const bar = Key('bar');
    await pumpFs(
      tester,
      _panel(
        headerProgress: const SizedBox(key: bar, height: 2),
        body: const SizedBox.expand(key: Key('body')),
      ),
    );
    expect(tester.getRect(find.byKey(bar)), const Rect.fromLTWH(0, 28, 360, 2));
    expect(tester.getTopLeft(find.byKey(const Key('body'))).dy, 28);
  });
}
