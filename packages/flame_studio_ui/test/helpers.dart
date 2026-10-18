import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The dark colours, for expectations.
const c = FsColors.dark;

/// Pumps [child] in the Studio theme, [width] wide, on a panel surface.
Future<void> pumpFs(
  WidgetTester tester,
  Widget child, {
  double width = 360,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: FsTheme.dark(),
      home: Material(
        color: c.surfacePanel,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

/// A mouse pointer, added at the top-left corner and removed after the
/// test.
Future<TestGesture> mouse(WidgetTester tester) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: const Offset(1, 599));
  addTearDown(gesture.removePointer);
  return gesture;
}

/// Moves the mouse over [finder] and pumps.
Future<void> hover(
  WidgetTester tester,
  TestGesture mouse,
  Finder finder,
) async {
  await mouse.moveTo(tester.getCenter(finder));
  await tester.pump();
}

/// Drags with the mouse from the centre of [finder] by [dx] pixels, in
/// [steps] moves, pumping after each.
Future<void> mouseDrag(
  WidgetTester tester,
  Finder finder,
  double dx, {
  int steps = 1,
}) async {
  final gesture = await tester.startGesture(
    tester.getCenter(finder),
    kind: PointerDeviceKind.mouse,
  );
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(Offset(dx / steps, 0));
    await tester.pump();
  }
  await gesture.up();
  await tester.pump();
}

/// The [BoxDecoration] of the first [Container] under [of] that has one.
BoxDecoration decorationIn(WidgetTester tester, Finder of) {
  final container = tester.widget<Container>(
    find
        .descendant(
          of: of,
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is BoxDecoration,
          ),
        )
        .first,
  );
  return container.decoration! as BoxDecoration;
}

/// The border colour of the first field box under [of].
Color fieldBorder(WidgetTester tester, Finder of) {
  final box = find
      .descendant(of: of, matching: find.byType(FsFieldBox), matchRoot: true)
      .first;
  final border = decorationIn(tester, box).border! as Border;
  return border.top.color;
}

/// The fill of the first field box under [of].
Color fieldFill(WidgetTester tester, Finder of) {
  final box = find
      .descendant(of: of, matching: find.byType(FsFieldBox), matchRoot: true)
      .first;
  return decorationIn(tester, box).color!;
}

/// The colour of the [Text] showing [text].
Color? textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

/// The text in the [index]th [EditableText].
String fieldText(WidgetTester tester, [int index = 0]) => tester
    .widget<EditableText>(find.byType(EditableText).at(index))
    .controller
    .text;

/// The text colour of the [index]th [EditableText].
Color? fieldTextColor(WidgetTester tester, [int index = 0]) => tester
    .widget<EditableText>(find.byType(EditableText).at(index))
    .style
    .color;

/// Whether a painter of type [P] is under [of].
bool hasPainter<P extends CustomPainter>(WidgetTester tester, Finder of) =>
    tester
        .widgetList<CustomPaint>(
          find.descendant(of: of, matching: find.byType(CustomPaint)),
        )
        .any((p) => p.foregroundPainter is P || p.painter is P);

/// Records screen-reader announcements (`SemanticsService`) until the test
/// ends.
List<String> announcements(WidgetTester tester) {
  final log = <String>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
    SystemChannels.accessibility,
    (message) async {
      final map = message as Map<Object?, Object?>;
      if (map['type'] == 'announce') {
        log.add((map['data']! as Map<Object?, Object?>)['message']! as String);
      }
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return log;
}
