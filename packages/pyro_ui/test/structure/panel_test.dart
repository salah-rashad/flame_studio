import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_ui/pyro_ui.dart';

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
  List<PrMenuEntry<void>> overflow = const [],
  Widget? headerProgress,
  FocusScopeNode? focusNode,
  Widget body = const SizedBox.expand(),
}) => SizedBox(
  height: 200,
  child: PrPanel(
    title: 'Scene',
    icon: PrIcons.listTree,
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
    final decoration = decorationIn(tester, find.byType(PrPanel));
    expect(decoration.color, c.surfaceRaised);
    expect((decoration.border! as Border).bottom.color, c.bgApp);
    expect(
      tester
          .widget<ColoredBox>(
            find
                .descendant(
                  of: find.byType(PrPanel),
                  matching: find.byType(ColoredBox),
                )
                .first,
          )
          .color,
      c.surfacePanel,
    );
    final title = tester.widget<Text>(find.text('Scene'));
    expect(title.style!.fontSize, PrText.heading.fontSize);
    expect(title.style!.fontWeight, PrText.heading.fontWeight);
    expect(tester.getSize(find.byIcon(PrIcons.listTree)), const Size(16, 16));
  });

  testWidgets('unfocused: secondary title and icon, no top edge', (
    tester,
  ) async {
    await pumpFs(tester, _panel());
    expect(textColor(tester, 'Scene'), c.textSecondary);
    expect(
      tester.widget<Icon>(find.byIcon(PrIcons.listTree)).color,
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
        body: const PrTreeRow<String>(depth: 0, name: 'Player', selected: true),
      ),
    );
    expect(
      decorationIn(tester, find.byType(PrTreeRow<String>)).color,
      c.surfaceSelectedInactive,
    );
    node.requestFocus();
    await tester.pump();
    expect(
      decorationIn(tester, find.byType(PrTreeRow<String>)).color,
      c.surfaceSelected,
    );
  });

  testWidgets('a click anywhere in the panel focuses it', (tester) async {
    await pumpFs(tester, _panel());
    await _click(tester, tester.getCenter(find.byType(PrPanel)));
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
      PrDebugStates(
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
          PrIconButton(
            icon: PrIcons.plus,
            tooltip: 'Add',
            size: PrIconButtonSize.small,
            onPressed: () {},
          ),
          PrIconButton(
            icon: PrIcons.filter,
            tooltip: 'Filter',
            size: PrIconButtonSize.small,
            onPressed: () {},
          ),
        ],
      ),
    );
    final add = tester.getRect(find.byType(PrIconButton).first);
    final filter = tester.getRect(find.byType(PrIconButton).last);
    expect(filter.right, 360 - 4);
    expect(filter.left - add.right, 4);
    expect(add.size, const Size(20, 20));
    expect(add.center.dy, closeTo(13.5, 0.01)); // centred above the 1px edge
  });

  test('more than 3 actions asserts', () {
    expect(
      () => PrPanel(
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
          PrMenuItem(label: 'Collapse all', onSelected: () => chose++),
        ],
      ),
    );
    expect(find.byIcon(PrIcons.more), findsOneWidget);
    await _click(tester, tester.getCenter(find.byIcon(PrIcons.more)));
    expect(find.text('Collapse all'), findsOneWidget);
    // Latched while open.
    expect(
      tester.widget<PrIconButton>(find.byType(PrIconButton)).selected,
      isTrue,
    );
    await _click(tester, tester.getCenter(find.text('Collapse all')));
    expect(chose, 1);
    expect(find.text('Collapse all'), findsNothing);
  });

  testWidgets('no ⋯ button without overflow entries', (tester) async {
    await pumpFs(tester, _panel());
    expect(find.byIcon(PrIcons.more), findsNothing);
  });

  testWidgets('forced part "overflow" reaches only the ⋯ button', (
    tester,
  ) async {
    await pumpFs(
      tester,
      PrDebugStates(
        states: const {WidgetState.hovered},
        part: 'overflow',
        child: _panel(
          actions: [
            PrIconButton(
              icon: PrIcons.lock,
              tooltip: 'Lock',
              size: PrIconButtonSize.small,
              onPressed: () {},
            ),
          ],
          overflow: [PrMenuItem(label: 'Reset', onSelected: () {})],
        ),
      ),
    );
    Color? fill(IconData icon) => decorationIn(
      tester,
      find.ancestor(of: find.byIcon(icon), matching: find.byType(PrIconButton)),
    ).color;
    expect(fill(PrIcons.more), c.surfaceHover);
    expect(fill(PrIcons.lock), Colors.transparent);
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
