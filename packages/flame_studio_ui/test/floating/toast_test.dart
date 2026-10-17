import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

Widget _left(Widget child) => Align(
  alignment: Alignment.topLeft,
  child: Padding(padding: const EdgeInsets.all(20), child: child),
);

/// Pumps a host filling the 800×600 window and returns its controller.
Future<FsToastController> _pumpHost(WidgetTester tester) async {
  late FsToastController controller;
  await tester.pumpWidget(
    MaterialApp(
      theme: FsTheme.dark(),
      home: FsToastHost(
        dismissTooltip: 'Dismiss',
        child: Builder(
          builder: (context) {
            controller = FsToastHost.of(context);
            return ColoredBox(color: c.surfacePanel);
          },
        ),
      ),
    ),
  );
  return controller;
}

FsToastData _data(String title, [FsToastKind kind = FsToastKind.warning]) =>
    FsToastData(kind: kind, title: title);

/// The titles on screen, top to bottom.
List<String> _titles(WidgetTester tester) {
  final toasts = tester.widgetList<FsToast>(find.byType(FsToast)).toList();
  final titles = [for (final t in toasts) t.data.title];
  titles.sort(
    (a, b) => tester
        .getTopLeft(find.text(a))
        .dy
        .compareTo(tester.getTopLeft(find.text(b)).dy),
  );
  return titles;
}

void main() {
  group('FsToast', () {
    final toast = find.byType(FsToast);

    testWidgets('320px, overlay surface, radius-md, popover shadow', (
      tester,
    ) async {
      await pumpFs(
        tester,
        _left(
          const FsToast(
            data: FsToastData(
              kind: FsToastKind.success,
              title: 'Hot reload complete',
              message: '3 libraries reloaded in 412 ms',
            ),
          ),
        ),
        width: 400,
      );
      expect(tester.getSize(toast).width, 320);
      final box = decorationIn(tester, toast);
      expect(box.color, c.surfaceOverlay);
      expect((box.border! as Border).top.color, c.borderOverlay);
      expect(box.borderRadius, FsRadii.md);
      expect(box.boxShadow, FsShadows.dark.popover);
      expect(textColor(tester, 'Hot reload complete'), c.textPrimary);
      expect(
        tester.widget<Text>(find.text('Hot reload complete')).style!.fontWeight,
        FsText.heading.fontWeight,
      );
      expect(
        textColor(tester, '3 libraries reloaded in 412 ms'),
        c.textSecondary,
      );
      expect(
        tester
            .widget<Text>(find.text('3 libraries reloaded in 412 ms'))
            .style!
            .fontSize,
        FsText.small.fontSize,
      );
    });

    for (final (kind, icon, ink) in [
      (FsToastKind.success, FsIcons.checkCircle, c.success),
      (FsToastKind.info, FsIcons.info, c.info),
      (FsToastKind.warning, FsIcons.alertTriangle, c.warning),
      (FsToastKind.error, FsIcons.alertCircle, c.error),
    ]) {
      testWidgets('${kind.name}: a 16px icon in its colour', (tester) async {
        await pumpFs(
          tester,
          _left(
            FsToast(
              data: FsToastData(kind: kind, title: 'Title'),
            ),
          ),
          width: 400,
        );
        final glyph = tester.widget<Icon>(find.byIcon(icon));
        expect(glyph.color, ink);
        expect(tester.getSize(find.byIcon(icon)), const Size.square(16));
      });
    }

    testWidgets('progress: an info spinner and an info bar', (tester) async {
      await pumpFs(
        tester,
        _left(
          const FsToast(
            data: FsToastData(
              kind: FsToastKind.progress,
              title: 'Importing 24 sprites…',
              dismissible: false,
              progress: 0.62,
            ),
          ),
        ),
        width: 400,
      );
      expect(
        tester.widget<FsSpinner>(find.byType(FsSpinner)).tone,
        FsProgressTone.background,
      );
      final bar = tester.widget<FsProgressBar>(find.byType(FsProgressBar));
      expect(bar.value, 0.62);
      expect(bar.tone, FsProgressTone.background);
      expect(find.byType(FsIconButton), findsNothing);
    });

    testWidgets('actions are ghost buttons and dismiss unless told not to', (
      tester,
    ) async {
      final log = <String>[];
      await pumpFs(
        tester,
        _left(
          FsToast(
            dismissTooltip: 'Dismiss',
            onDismiss: () => log.add('dismiss'),
            data: FsToastData(
              kind: FsToastKind.error,
              title: 'Hot reload failed',
              actions: [
                FsToastAction(
                  label: 'Show in console',
                  onPressed: () => log.add('console'),
                ),
                FsToastAction(
                  label: 'Restart game',
                  dismisses: false,
                  onPressed: () => log.add('restart'),
                ),
              ],
            ),
          ),
        ),
        width: 400,
      );
      for (final b in tester.widgetList<FsButton>(find.byType(FsButton))) {
        expect(b.variant, FsButtonVariant.ghost);
      }
      // The first label lines up with the title (as in the design, the
      // button's 1px transparent edge is left over).
      expect(
        tester.getTopLeft(find.text('Show in console')).dx,
        tester.getTopLeft(find.text('Hot reload failed')).dx + 1,
      );
      await tester.tap(find.text('Show in console'));
      await tester.tap(find.text('Restart game'));
      await tester.tap(find.byIcon(FsIcons.x));
      expect(log, ['console', 'dismiss', 'restart', 'dismiss']);
    });

    testWidgets('at most two actions', (tester) async {
      await pumpFs(
        tester,
        _left(
          FsToast(
            data: FsToastData(
              kind: FsToastKind.info,
              title: 't',
              actions: [
                for (var i = 0; i < 3; i++)
                  FsToastAction(label: '$i', onPressed: () {}),
              ],
            ),
          ),
        ),
        width: 400,
      );
      expect(tester.takeException(), isAssertionError);
    });
  });

  group('FsToastHost', () {
    testWidgets('bottom right, 16px in; fades in over 200ms', (tester) async {
      final toasts = await _pumpHost(tester);
      toasts.show(_data('Saved'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final fade = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(FsToastHost),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(fade.opacity.value, closeTo(Curves.easeOut.transform(0.5), 1e-6));
      await tester.pump(const Duration(milliseconds: 100));
      expect(fade.opacity.value, 1);
      final rect = tester.getRect(find.byType(FsToast));
      expect(rect.right, 800 - 16);
      expect(rect.bottom, 600 - 16);
    });

    testWidgets('newest on top, 8px apart, at most 3; older ones wait', (
      tester,
    ) async {
      final toasts = await _pumpHost(tester);
      final handles = [
        for (final title in ['one', 'two', 'three']) toasts.show(_data(title)),
      ];
      await tester.pumpAndSettle();
      expect(_titles(tester), ['three', 'two', 'one']);
      final top = tester.getRect(find.widgetWithText(FsToast, 'two'));
      final below = tester.getRect(find.widgetWithText(FsToast, 'one'));
      expect(below.top - top.bottom, 8);

      toasts.show(_data('four'));
      await tester.pumpAndSettle();
      expect(_titles(tester), ['four', 'three', 'two']);
      expect(handles[0].isActive, isTrue);

      handles[2].dismiss();
      await tester.pumpAndSettle();
      expect(_titles(tester), ['four', 'two', 'one']);
      expect(handles[2].isActive, isFalse);
    });

    testWidgets('success and info go after 4s; warning and error stay', (
      tester,
    ) async {
      final toasts = await _pumpHost(tester);
      final ok = toasts.show(_data('Hot reload complete', FsToastKind.success));
      toasts
        ..show(_data('Heads up', FsToastKind.info))
        ..show(_data('2 nodes reference deleted assets'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 3900));
      expect(ok.isActive, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(ok.isActive, isFalse);
      await tester.pumpAndSettle();
      expect(_titles(tester), ['2 nodes reference deleted assets']);
      await tester.pump(const Duration(seconds: 10));
      expect(_titles(tester), ['2 nodes reference deleted assets']);
    });

    testWidgets('the countdown pauses while hovered', (tester) async {
      final toasts = await _pumpHost(tester);
      final ok = toasts.show(_data('Saved', FsToastKind.success));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: tester.getCenter(find.text('Saved')));
      addTearDown(pointer.removePointer);
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      expect(ok.isActive, isTrue);
      await pointer.moveTo(const Offset(10, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1800));
      expect(ok.isActive, isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      expect(ok.isActive, isFalse);
      await tester.pumpAndSettle();
    });

    testWidgets('update replaces the content and restarts the countdown', (
      tester,
    ) async {
      final toasts = await _pumpHost(tester);
      final import = toasts.show(
        const FsToastData(
          kind: FsToastKind.progress,
          title: 'Importing 24 sprites…',
          progress: 0.1,
          dismissible: false,
        ),
      );
      // The spinner never settles: pump fixed times.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      import.update(
        const FsToastData(
          kind: FsToastKind.progress,
          title: 'Importing 24 sprites…',
          progress: 0.62,
          dismissible: false,
        ),
      );
      await tester.pump();
      expect(
        tester.widget<FsProgressBar>(find.byType(FsProgressBar)).value,
        0.62,
      );
      await tester.pump(const Duration(seconds: 10));
      expect(import.isActive, isTrue);
      import.update(_data('Imported 24 sprites', FsToastKind.success));
      await tester.pump();
      expect(find.text('Imported 24 sprites'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 3800));
      expect(import.isActive, isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      expect(import.isActive, isFalse);
      await tester.pumpAndSettle();
      expect(find.byType(FsToast), findsNothing);
      // A gone toast ignores further calls.
      import
        ..update(_data('again'))
        ..dismiss();
      await tester.pump();
      expect(find.byType(FsToast), findsNothing);
    });

    testWidgets('the × dismisses, with a 200ms exit', (tester) async {
      final toasts = await _pumpHost(tester);
      final handle = toasts.show(_data('Build failed', FsToastKind.error));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(FsIcons.x));
      await tester.pump();
      expect(handle.isActive, isFalse);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(FsToast), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 101));
      await tester.pump();
      expect(find.byType(FsToast), findsNothing);
    });
  });
}
