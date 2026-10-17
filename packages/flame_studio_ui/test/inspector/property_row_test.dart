import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

Widget _row({
  FsValueSource source = FsValueSource.codeDefault,
  VoidCallback? onReset,
  bool enabled = true,
  bool readOnly = false,
  String? error,
  FsScrubHandle? labelScrub,
}) => FsPropertyRow(
  label: 'jumpForce',
  source: source,
  onReset: onReset,
  resetTooltip: 'Reset to default',
  enabled: enabled,
  readOnly: readOnly,
  error: error,
  labelScrub: labelScrub,
  editor: const SizedBox(height: 20),
);

Color _rowFill(WidgetTester tester) => tester
    .widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(FsPropertyRow),
            matching: find.byType(ColoredBox),
          )
          .first,
    )
    .color;

void main() {
  final row = find.byType(FsPropertyRow);

  testWidgets('24px high; label column 40%, at least 72px', (tester) async {
    await pumpFs(tester, _row(), width: 420);
    expect(tester.getSize(row).height, FsSizes.rowProperty);
    // 420 - 16 left - 4 right padding = 400; 40% = 160.
    final label = find
        .ancestor(of: find.text('jumpForce'), matching: find.byType(SizedBox))
        .first;
    expect(tester.getSize(label).width, 160);

    await pumpFs(tester, _row(), width: 150);
    final narrow = find
        .ancestor(of: find.text('jumpForce'), matching: find.byType(SizedBox))
        .first;
    expect(tester.getSize(narrow).width, 72);
  });

  testWidgets('default from code: secondary label, no bar, no reset', (
    tester,
  ) async {
    await pumpFs(tester, _row(onReset: () {}));
    final style = tester.widget<Text>(find.text('jumpForce')).style!;
    expect(style.color, c.textSecondary);
    expect(style.fontWeight, FontWeight.w400);
    expect(find.byIcon(FsIcons.reset), findsNothing);
    expect(find.byType(PositionedDirectional), findsNothing);
  });

  testWidgets('overridden: bar, primary 500 label, reset', (tester) async {
    var resets = 0;
    await pumpFs(
      tester,
      _row(source: FsValueSource.overridden, onReset: () => resets++),
    );
    final style = tester.widget<Text>(find.text('jumpForce')).style!;
    expect(style.color, c.textPrimary);
    expect(style.fontWeight, FontWeight.w500);
    final bar = tester.widget<PositionedDirectional>(
      find.byType(PositionedDirectional),
    );
    expect(bar.width, 2);
    expect(
      ((bar.child as DecoratedBox).decoration as BoxDecoration).color,
      c.accentText,
    );
    await tester.tap(find.byIcon(FsIcons.reset));
    expect(resets, 1);
  });

  testWidgets('overridden without onReset shows no reset', (tester) async {
    await pumpFs(tester, _row(source: FsValueSource.overridden));
    expect(find.byIcon(FsIcons.reset), findsNothing);
  });

  testWidgets('hover fills the whole row', (tester) async {
    await pumpFs(tester, _row());
    expect(_rowFill(tester), Colors.transparent);
    final m = await mouse(tester);
    await hover(tester, m, row);
    expect(_rowFill(tester), c.surfaceHover);
  });

  testWidgets('forced row hover', (tester) async {
    await pumpFs(
      tester,
      FsDebugStates(states: const {WidgetState.hovered}, child: _row()),
    );
    expect(_rowFill(tester), c.surfaceHover);
  });

  testWidgets('error: error label', (tester) async {
    await pumpFs(tester, _row(error: 'Expected a number'));
    expect(textColor(tester, 'jumpForce'), c.error);
  });

  testWidgets('disabled and read-only: text-disabled label', (tester) async {
    await pumpFs(tester, _row(enabled: false));
    expect(textColor(tester, 'jumpForce'), c.textDisabled);
    await pumpFs(tester, _row(readOnly: true));
    expect(textColor(tester, 'jumpForce'), c.textDisabled);
  });

  testWidgets('scrub label: hover primary + dotted underline, active accent', (
    tester,
  ) async {
    final handle = FsScrubHandle(
      onStart: () {},
      onUpdate: (_, _) {},
      onEnd: () {},
    );
    await pumpFs(tester, _row(labelScrub: handle));
    final m = await mouse(tester);
    await hover(tester, m, find.text('jumpForce'));
    final style = tester.widget<Text>(find.text('jumpForce')).style!;
    expect(style.color, c.textPrimary);
    expect(style.decoration, TextDecoration.underline);
    expect(style.decorationStyle, TextDecorationStyle.dotted);

    await pumpFs(
      tester,
      _row(
        labelScrub: FsScrubHandle(
          onStart: () {},
          onUpdate: (_, _) {},
          onEnd: () {},
          active: true,
        ),
      ),
    );
    expect(textColor(tester, 'jumpForce'), c.accentText);
  });

  testWidgets('the label of a scrub handle shows the resize cursor', (
    tester,
  ) async {
    final handle = FsScrubHandle(
      onStart: () {},
      onUpdate: (_, _) {},
      onEnd: () {},
    );
    await pumpFs(tester, _row(labelScrub: handle));
    final region = tester.widgetList<MouseRegion>(
      find.ancestor(
        of: find.text('jumpForce'),
        matching: find.byType(MouseRegion),
      ),
    );
    expect(
      region.map((r) => r.cursor),
      contains(SystemMouseCursors.resizeLeftRight),
    );
  });
}
