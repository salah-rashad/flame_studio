import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

const _bounds = Size(800, 600);

void main() {
  group('FsOverlayPlacement', () {
    Offset place(
      Rect anchor,
      Size size, {
      FsOverlaySide side = FsOverlaySide.below,
      FsOverlayAlign align = FsOverlayAlign.start,
      bool flip = false,
    }) => FsOverlayPlacement.place(
      anchor: anchor,
      size: size,
      bounds: _bounds,
      side: side,
      align: align,
      flipHorizontally: flip,
    );

    test('below the anchor with a 4px gap, left edges aligned', () {
      expect(
        place(const Rect.fromLTWH(100, 100, 80, 24), const Size(200, 100)),
        const Offset(100, 128),
      );
    });

    test('centred and end alignment', () {
      const anchor = Rect.fromLTWH(100, 100, 80, 24);
      expect(
        place(anchor, const Size(40, 20), align: FsOverlayAlign.center),
        const Offset(120, 128),
      );
      expect(
        place(anchor, const Size(40, 20), align: FsOverlayAlign.end),
        const Offset(140, 128),
      );
    });

    test('flips above when below does not fit', () {
      expect(
        place(const Rect.fromLTWH(100, 540, 80, 24), const Size(200, 100)),
        const Offset(100, 436), // 540 - 4 - 100
      );
    });

    test('stays below when above has even less room', () {
      // 120px tall in a window where neither side fits: below has more room.
      final p = place(
        const Rect.fromLTWH(100, 200, 80, 24),
        const Size(200, 500),
      );
      // Below (364px of room) beats above (188px); shifted up to fit.
      expect(p.dy, 600 - 8 - 500);
    });

    test('prefers above when asked, flips below at the top', () {
      const size = Size(100, 40);
      expect(
        place(
          const Rect.fromLTWH(100, 300, 80, 24),
          size,
          side: FsOverlaySide.above,
        ).dy,
        256,
      );
      expect(
        place(
          const Rect.fromLTWH(100, 10, 80, 24),
          size,
          side: FsOverlaySide.above,
        ).dy,
        38,
      );
    });

    test('shifts left to stay 8px inside the window', () {
      expect(
        place(const Rect.fromLTWH(700, 100, 80, 24), const Size(248, 100)).dx,
        800 - 8 - 248,
      );
    });

    test('at a point, flips to the left when there is no room', () {
      const at = Rect.fromLTWH(700, 100, 0, 0);
      expect(place(at, const Size(248, 100), flip: true).dx, 700 - 248);
      expect(
        place(
          const Rect.fromLTWH(100, 100, 0, 0),
          const Size(248, 100),
          flip: true,
        ).dx,
        100,
      );
    });
  });

  group('FsAnchoredOverlay', () {
    late OverlayPortalController controller;
    var dismissals = 0;

    setUp(() {
      controller = OverlayPortalController();
      dismissals = 0;
    });

    Widget anchored({Offset? position, double top = 100, bool match = false}) =>
        Padding(
          padding: EdgeInsets.only(left: 100, top: top),
          child: Align(
            alignment: Alignment.topLeft,
            child: FsAnchoredOverlay(
              controller: controller,
              position: position,
              matchAnchorWidth: match,
              onDismiss: () {
                dismissals++;
                controller.hide();
              },
              overlayBuilder: (context) => Container(
                key: const Key('layer'),
                width: match ? 40 : 200,
                height: 100,
                color: c.surfaceOverlay,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: controller.toggle,
                child: const SizedBox(
                  key: Key('anchor'),
                  width: 80,
                  height: 24,
                ),
              ),
            ),
          ),
        );

    Future<void> pump(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = _bounds;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpFs(tester, child, width: 800);
    }

    final layer = find.byKey(const Key('layer'));
    final anchor = find.byKey(const Key('anchor'));

    testWidgets('opens below the anchor; tapping the anchor toggles it', (
      tester,
    ) async {
      await pump(tester, anchored());
      expect(layer, findsNothing);
      await tester.tap(anchor);
      await tester.pump();
      expect(tester.getTopLeft(layer), const Offset(100, 128));
      await tester.tap(anchor);
      await tester.pump();
      expect(layer, findsNothing);
      expect(dismissals, 0);
    });

    testWidgets('flips above near the bottom of the window', (tester) async {
      await pump(tester, anchored(top: 540));
      controller.show();
      await tester.pump();
      expect(tester.getTopLeft(layer).dy, 540 - 4 - 100);
    });

    testWidgets('opens at a point relative to the anchor', (tester) async {
      await pump(tester, anchored(position: const Offset(10, 12)));
      controller.show();
      await tester.pump();
      expect(tester.getTopLeft(layer), const Offset(110, 112));
    });

    testWidgets('matchAnchorWidth makes the layer as wide as the anchor', (
      tester,
    ) async {
      await pump(tester, anchored(match: true));
      controller.show();
      await tester.pump();
      expect(tester.getSize(layer).width, 80);
    });

    testWidgets('a tap outside dismisses; a tap inside does not', (
      tester,
    ) async {
      await pump(tester, anchored());
      controller.show();
      await tester.pump();
      await tester.tap(layer);
      await tester.pump();
      expect(dismissals, 0);
      await tester.tapAt(const Offset(600, 500), kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(dismissals, 1);
      expect(layer, findsNothing);
    });

    testWidgets('Esc dismisses while focus is inside', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await pump(
        tester,
        FsAnchoredOverlay(
          controller: controller,
          onDismiss: () {
            dismissals++;
            controller.hide();
          },
          overlayBuilder: (context) => Focus(
            focusNode: node,
            autofocus: true,
            child: const SizedBox(key: Key('layer'), width: 100, height: 40),
          ),
          child: const SizedBox(width: 80, height: 24),
        ),
      );
      controller.show();
      await tester.pump();
      await tester.pump();
      expect(node.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(dismissals, 1);
      expect(layer, findsNothing);
    });

    testWidgets('Esc passes through when nothing is open', (tester) async {
      var outer = 0;
      final node = FocusNode();
      addTearDown(node.dispose);
      await pump(
        tester,
        Actions(
          actions: {
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (_) => outer++,
            ),
          },
          child: FsAnchoredOverlay(
            controller: controller,
            onDismiss: () => dismissals++,
            overlayBuilder: (context) => const SizedBox(),
            child: Focus(
              focusNode: node,
              autofocus: true,
              child: const SizedBox(width: 80, height: 24),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(dismissals, 0);
      expect(outer, 1);
    });

    testWidgets('the layer inherits the theme of its anchor', (tester) async {
      late FsColors seen;
      await pump(
        tester,
        FsAnchoredOverlay(
          controller: controller..show(),
          overlayBuilder: (context) {
            seen = FsColors.of(context);
            return const SizedBox(width: 10, height: 10);
          },
          child: const SizedBox(width: 80, height: 24),
        ),
      );
      expect(seen, FsColors.dark);
    });
  });
}
