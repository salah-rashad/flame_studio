import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/gestures.dart';
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

  group('FsPropertyList', () {
    testWidgets('rows share the label fraction', (tester) async {
      await pumpFs(tester, _list(fraction: 0.5), width: 420);
      // 420 - 16 - 4 = 400 of content; half is the label.
      for (final name in ['speed', 'gravity', 'debugMode']) {
        expect(_labelWidth(tester, name), 200);
      }
    });

    testWidgets('dragging the boundary resizes every row; one report', (
      tester,
    ) async {
      final reports = <double>[];
      await pumpFs(tester, _list(onChanged: reports.add), width: 420);
      // The boundary: 16 padding + 160 label, then the 4px gap.
      final boundary = tester.getTopLeft(find.text('gravity')).dy;
      final start = Offset(16 + 160 + 2, boundary + 4);
      final gesture = await tester.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      expect(_lines(tester), everyElement(c.accentText));
      await gesture.up();
      await tester.pump();
      for (final name in ['speed', 'gravity', 'debugMode']) {
        expect(_labelWidth(tester, name), 200);
      }
      expect(reports, [0.5]);
      await gesture.removePointer();
    });

    testWidgets('the label keeps 72px, the editor 72px plus reset', (
      tester,
    ) async {
      await pumpFs(tester, _list(), width: 420);
      await tester.dragFrom(
        Offset(16 + 160 + 2, tester.getCenter(find.text('speed')).dy),
        const Offset(-300, 0),
      );
      await tester.pump();
      expect(_labelWidth(tester, 'speed'), 72);
      await tester.dragFrom(
        Offset(16 + 72 + 2, tester.getCenter(find.text('speed')).dy),
        const Offset(600, 0),
      );
      await tester.pump();
      // 400 - (72 + 4 + 4 + 20).
      expect(_labelWidth(tester, 'speed'), 300);
    });

    testWidgets('hovering the boundary shows the line in every row', (
      tester,
    ) async {
      await pumpFs(tester, _list(), width: 420);
      expect(_lines(tester), everyElement(Colors.transparent));
      final m = await mouse(tester);
      await m.moveTo(
        Offset(16 + 160 + 2, tester.getCenter(find.text('speed')).dy),
      );
      await tester.pump();
      expect(_lines(tester), hasLength(3));
      expect(_lines(tester), everyElement(c.borderStrong));
    });

    testWidgets('a row outside a list has no handle', (tester) async {
      await pumpFs(tester, _row(), width: 420);
      expect(
        find.byWidgetPredicate((w) => w is SizedBox && w.width == 1),
        findsNothing,
      );
    });
  });
}

Widget _list({ValueChanged<double>? onChanged, double fraction = 0.4}) =>
    FsPropertyList(
      initialLabelFraction: fraction,
      onLabelFractionChanged: onChanged,
      children: [
        for (final name in ['speed', 'gravity', 'debugMode'])
          FsPropertyRow(label: name, editor: const SizedBox(height: 20)),
      ],
    );

double _labelWidth(WidgetTester tester, String text) => tester
    .getSize(
      find.ancestor(of: find.text(text), matching: find.byType(SizedBox)).first,
    )
    .width;

/// The colours of the rows' 1px boundary lines.
Iterable<Color> _lines(WidgetTester tester) => tester
    .widgetList<SizedBox>(
      find.descendant(
        of: find.byType(FsPropertyList),
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 1 && w.child is ColoredBox,
        ),
      ),
    )
    .map((s) => (s.child! as ColoredBox).color);
