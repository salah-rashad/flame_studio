import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_ui/pyro_ui.dart';

/// The dark colours, for expectations.
const c = PrColors.dark;

/// Pumps [child] in Pyro theme on a panel surface inside a `ProviderScope`
/// — the app-side harness the panel widget tests share (spec 006, T004),
/// modeled on pyro_ui's `pumpFs` plus the scope the app always has.
/// [scope] replaces the default plain `ProviderScope` wrapper, so a test
/// can inject its own container or overrides.
Future<void> pumpPyro(
  WidgetTester tester,
  Widget child, {
  double width = 360,
  Widget Function(Widget child)? scope,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: PrTheme.dark(),
      home: Material(
        color: c.surfacePanel,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: (scope ?? (child) => ProviderScope(child: child))(child),
          ),
        ),
      ),
    ),
  );
}

/// A mouse pointer, added at the bottom-left corner and removed after the
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

/// Drags with the mouse from the centre of [finder] to [target] in [steps]
/// moves, pumping after each — reparenting tests drop on a row's zone, so
/// the drag takes real coordinates rather than a delta.
Future<void> mouseDragTo(
  WidgetTester tester,
  Finder finder,
  Offset target, {
  int steps = 5,
}) async {
  final start = tester.getCenter(finder);
  final gesture = await tester.startGesture(
    start,
    kind: PointerDeviceKind.mouse,
  );
  addTearDown(gesture.removePointer);
  for (var i = 1; i <= steps; i++) {
    await gesture.moveTo(
      Offset.lerp(start, target, i / steps)!,
      timeStamp: Duration(milliseconds: 16 * i),
    );
    await tester.pump();
  }
  await gesture.up();
  await tester.pump();
}
