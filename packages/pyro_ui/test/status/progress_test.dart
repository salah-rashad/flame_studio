import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../helpers.dart';

Widget _left(Widget child, {bool reduceMotion = false}) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: Align(
      alignment: Alignment.topLeft,
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    ),
  ),
);

/// The render object of the [CustomPaint] under [of].
RenderObject _painted(WidgetTester tester, Finder of) => tester.renderObject(
  find.descendant(of: of, matching: find.byType(CustomPaint)).first,
);

/// A painted arc starting at [start] (within 1e-6) in [color].
PaintPatternPredicate _arcAt(double start, Color color) =>
    (Symbol name, List<dynamic> args) {
      if (name != #drawArc) return false;
      final paint = args[4] as Paint;
      return ((args[1] as double) - start).abs() < 1e-6 &&
          paint.color.toARGB32() == color.toARGB32();
    };

void main() {
  group('PrProgressBar', () {
    final bar = find.byType(PrProgressBar);

    testWidgets('determinate: 2px track and a left-aligned fill', (
      tester,
    ) async {
      await pumpFs(
        tester,
        _left(const SizedBox(width: 200, child: PrProgressBar(value: 0.62))),
      );
      expect(tester.getSize(bar), const Size(200, 2));
      expect(
        _painted(tester, bar),
        paints
          ..rect(
            rect: const Rect.fromLTWH(0, 0, 200, 2),
            color: c.surfacePressed,
          )
          ..rect(rect: const Rect.fromLTWH(0, 0, 124, 2), color: c.accentText),
      );
    });

    testWidgets('background tone draws info; values are clamped', (
      tester,
    ) async {
      await pumpFs(
        tester,
        _left(
          const SizedBox(
            width: 100,
            child: PrProgressBar(value: 1.5, tone: PrProgressTone.background),
          ),
        ),
      );
      expect(
        _painted(tester, bar),
        paints
          ..rect(color: c.surfacePressed)
          ..rect(rect: const Rect.fromLTWH(0, 0, 100, 2), color: c.info),
      );
    });

    testWidgets('semantics: the label and the percentage', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpFs(
        tester,
        _left(
          const SizedBox(
            width: 100,
            child: PrProgressBar(value: 0.25, semanticsLabel: 'Importing'),
          ),
        ),
      );
      expect(
        tester.getSemantics(bar),
        matchesSemantics(label: 'Importing', value: '25%'),
      );
      handle.dispose();
    });

    for (final reduce in [false, true]) {
      testWidgets('indeterminate: a 30% segment slides over '
          '${reduce ? '3s (reduce motion)' : '1.2s'}', (tester) async {
        await pumpFs(
          tester,
          _left(
            const SizedBox(width: 100, child: PrProgressBar()),
            reduceMotion: reduce,
          ),
        );
        await tester.pump(); // the loop's first tick
        await tester.pump(const Duration(milliseconds: 600));
        final t = reduce ? 0.2 : 0.5;
        final left = (-0.3 + 1.3 * Curves.fastOutSlowIn.transform(t)) * 100;
        expect(
          _painted(tester, bar),
          paints
            ..rect(color: c.surfacePressed)
            ..something((name, args) {
              if (name != #drawRect) return false;
              final rect = args[0] as Rect;
              return (rect.left - left).abs() < 1e-6 &&
                  (rect.width - 30).abs() < 1e-6 &&
                  (args[1] as Paint).color.toARGB32() ==
                      c.accentText.toARGB32();
            }),
        );
      });
    }
  });

  group('PrSpinner', () {
    final spinner = find.byType(PrSpinner);

    testWidgets('14px by default, 16 in toolbars', (tester) async {
      await pumpFs(tester, _left(const PrSpinner()));
      expect(tester.getSize(spinner), const Size.square(14));
      await pumpFs(tester, _left(const PrSpinner(size: 16)));
      expect(tester.getSize(spinner), const Size.square(16));
    });

    testWidgets('a surface-pressed ring under an accent-text quarter arc', (
      tester,
    ) async {
      await pumpFs(tester, _left(const PrSpinner()));
      expect(
        _painted(tester, spinner),
        paints
          ..circle(
            x: 7,
            y: 7,
            radius: 6,
            color: c.surfacePressed,
            strokeWidth: 2,
          )
          ..arc(
            rect: const Rect.fromLTWH(1, 1, 12, 12),
            startAngle: -0.75 * math.pi,
            sweepAngle: math.pi / 2,
            color: c.accentText,
          ),
      );
      await pumpFs(
        tester,
        _left(const PrSpinner(tone: PrProgressTone.background)),
      );
      expect(_painted(tester, spinner), paints..arc(color: c.info));
    });

    for (final reduce in [false, true]) {
      testWidgets('turns every ${reduce ? '3s (reduce motion)' : '0.8s'}', (
        tester,
      ) async {
        await pumpFs(tester, _left(const PrSpinner(), reduceMotion: reduce));
        await tester.pump(); // the loop's first tick
        await tester.pump(const Duration(milliseconds: 600));
        final t = reduce ? 0.2 : 0.75;
        expect(
          _painted(tester, spinner),
          paints
            ..circle()
            ..something(
              _arcAt(-0.75 * math.pi + t * 2 * math.pi, c.accentText),
            ),
        );
      });
    }
  });

  group('PrStatusDot', () {
    for (final (status, fill) in [
      (PrStatus.idle, c.statusIdle),
      (PrStatus.working, c.info),
      (PrStatus.ok, c.success),
      (PrStatus.error, c.error),
    ]) {
      testWidgets('${status.name}: an 8px dot and a small label', (
        tester,
      ) async {
        await pumpFs(tester, _left(PrStatusDot(status: status, label: 'Word')));
        final dot = find.descendant(
          of: find.byType(PrStatusDot),
          matching: find.byType(Container),
        );
        expect(tester.getSize(dot), const Size.square(8));
        expect(decorationIn(tester, find.byType(PrStatusDot)).color, fill);
        expect(textColor(tester, 'Word'), c.textSecondary);
        expect(
          tester.widget<Text>(find.text('Word')).style!.fontSize,
          PrText.small.fontSize,
        );
        expect(
          tester.getTopLeft(find.text('Word')).dx - tester.getTopRight(dot).dx,
          6,
        );
      });
    }

    double opacity(WidgetTester tester) => tester
        .widget<Opacity>(
          find.descendant(
            of: find.byType(PrStatusDot),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;

    testWidgets('only working pulses, down to .35 halfway', (tester) async {
      await pumpFs(
        tester,
        _left(const PrStatusDot(status: PrStatus.ok, label: 'Running')),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(opacity(tester), 1);
      await pumpFs(
        tester,
        _left(const PrStatusDot(status: PrStatus.working, label: 'Reloading')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(opacity(tester), closeTo(0.35, 1e-6));
      await tester.pump(const Duration(milliseconds: 600));
      expect(opacity(tester), closeTo(1, 1e-6));
    });

    testWidgets('reduce motion slows the pulse to 3s', (tester) async {
      await pumpFs(
        tester,
        _left(
          const PrStatusDot(status: PrStatus.working, label: 'Reloading'),
          reduceMotion: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        opacity(tester),
        closeTo(1 - 0.65 * Curves.easeInOut.transform(0.4), 1e-6),
      );
      await tester.pump(const Duration(milliseconds: 900));
      expect(opacity(tester), closeTo(0.35, 1e-6));
    });
  });

  group('PrDelayedProgress', () {
    Widget delayed(bool busy) =>
        _left(PrDelayedProgress(busy: busy, child: const Text('progress')));

    testWidgets('shows the child only after 300ms of work', (tester) async {
      await pumpFs(tester, delayed(true));
      expect(find.text('progress'), findsNothing);
      await tester.pump(const Duration(milliseconds: 299));
      expect(find.text('progress'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('progress'), findsOneWidget);
      await pumpFs(tester, delayed(false));
      expect(find.text('progress'), findsNothing);
    });

    testWidgets('quick work never shows it', (tester) async {
      await pumpFs(tester, delayed(false));
      await pumpFs(tester, delayed(true));
      await tester.pump(const Duration(milliseconds: 200));
      await pumpFs(tester, delayed(false));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('progress'), findsNothing);
      // Starting again restarts the delay.
      await pumpFs(tester, delayed(true));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('progress'), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('progress'), findsOneWidget);
    });
  });
}
