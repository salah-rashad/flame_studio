import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

Widget _left(Widget child) => Align(
  alignment: Alignment.topLeft,
  child: Padding(padding: const EdgeInsets.all(20), child: child),
);

void main() {
  group('FsBadge', () {
    final badge = find.byType(FsBadge);

    for (final (kind, fill, ink, icon) in [
      (FsBadgeKind.warning, c.warningSubtle, c.warning, FsIcons.alertTriangle),
      (FsBadgeKind.error, c.errorSubtle, c.error, FsIcons.alertCircle),
      (FsBadgeKind.missing, c.errorSubtle, c.error, FsIcons.alertCircle),
      (FsBadgeKind.prefab, c.prefabSubtle, c.prefab, null),
      (FsBadgeKind.info, c.infoSubtle, c.info, null),
      (FsBadgeKind.success, c.successSubtle, c.success, FsIcons.check),
      (FsBadgeKind.neutral, c.surfacePressed, c.textPrimary, null),
      (FsBadgeKind.accent, c.accentSubtle, c.accentText, null),
    ]) {
      testWidgets('${kind.name}: colours and icon', (tester) async {
        await pumpFs(tester, _left(FsBadge(kind: kind, label: 'Word')));
        expect(decorationIn(tester, badge).color, fill);
        expect(textColor(tester, 'Word'), ink);
        final icons = tester.widgetList<Icon>(
          find.descendant(of: badge, matching: find.byType(Icon)),
        );
        expect(icons.map((i) => i.icon), [?icon]);
        for (final i in icons) {
          expect(i.color, ink);
          expect(i.size, 12);
        }
      });
    }

    testWidgets('16px, radius-xs, caption; pill is round', (tester) async {
      await pumpFs(
        tester,
        _left(const FsBadge(kind: FsBadgeKind.prefab, label: 'Prefab')),
      );
      expect(tester.getSize(badge).height, 16);
      expect(decorationIn(tester, badge).borderRadius, FsRadii.xs);
      expect(
        tester.widget<Text>(find.text('Prefab')).style!.fontFamily,
        FsText.caption.fontFamily,
      );
      await pumpFs(
        tester,
        _left(const FsBadge(kind: FsBadgeKind.warning, count: 3, pill: true)),
      );
      expect(decorationIn(tester, badge).borderRadius, FsRadii.full);
    });

    testWidgets('a bare count is set in mono', (tester) async {
      await pumpFs(
        tester,
        _left(const FsBadge(kind: FsBadgeKind.neutral, count: 24)),
      );
      expect(
        tester.widget<Text>(find.text('24')).style!.fontFamily,
        FsText.monoSmall.fontFamily,
      );
    });

    testWidgets('a given icon replaces the kind\'s', (tester) async {
      await pumpFs(
        tester,
        _left(
          const FsBadge(
            kind: FsBadgeKind.info,
            label: 'Running',
            icon: FsIcons.zap,
          ),
        ),
      );
      expect(find.byIcon(FsIcons.zap), findsOneWidget);
    });

    testWidgets('showIcon: false drops the kind\'s icon', (tester) async {
      await pumpFs(
        tester,
        _left(
          const FsBadge(kind: FsBadgeKind.warning, count: 2, showIcon: false),
        ),
      );
      expect(find.byType(Icon), findsNothing);
      expect(textColor(tester, '2'), c.warning);
    });
  });

  group('FsDeviceChip', () {
    final chip = find.byType(FsDeviceChip);

    Widget sample({
      bool selected = false,
      bool error = false,
      bool enabled = true,
      Set<WidgetState> forced = const {},
      VoidCallback? onPressed,
    }) {
      final widget = FsDeviceChip(
        icon: FsIcons.smartphone,
        label: 'iPhone 15',
        detail: error ? 'offline' : '852×393',
        selected: selected,
        error: error,
        onPressed: enabled ? (onPressed ?? () {}) : null,
      );
      return _left(
        forced.isEmpty ? widget : FsDebugStates(states: forced, child: widget),
      );
    }

    (Color?, Color?, Color?) look(WidgetTester tester) {
      final d = decorationIn(tester, chip);
      final icon = tester.widget<Icon>(
        find.descendant(of: chip, matching: find.byType(Icon)),
      );
      return (d.color, (d.border! as Border).top.color, icon.color);
    }

    testWidgets('24px; name small, detail mono secondary', (tester) async {
      await pumpFs(tester, sample());
      expect(tester.getSize(chip).height, 24);
      expect(look(tester), (c.surfaceRaised, c.borderSubtle, c.textSecondary));
      expect(textColor(tester, 'iPhone 15'), c.textPrimary);
      expect(textColor(tester, '852×393'), c.textSecondary);
      expect(
        tester.widget<Text>(find.text('852×393')).style!.fontFamily,
        FsText.monoSmall.fontFamily,
      );
    });

    testWidgets('hover, pressed', (tester) async {
      await pumpFs(tester, sample(forced: {WidgetState.hovered}));
      expect(look(tester), (c.surfaceHover, c.borderControl, c.textSecondary));
      await pumpFs(tester, sample(forced: {WidgetState.pressed}));
      expect(look(tester).$1, c.surfacePressed);
    });

    testWidgets('selected keeps its look on hover', (tester) async {
      await pumpFs(
        tester,
        sample(selected: true, forced: {WidgetState.hovered}),
      );
      expect(look(tester), (c.accentSubtle, c.accentText, c.accentText));
    });

    testWidgets('error: error edge and the alert icon', (tester) async {
      await pumpFs(tester, sample(error: true));
      expect(look(tester), (c.surfaceRaised, c.error, c.error));
      expect(find.byIcon(FsIcons.alertCircle), findsOneWidget);
      expect(find.text('offline'), findsOneWidget);
    });

    testWidgets('disabled: everything text-disabled', (tester) async {
      await pumpFs(tester, sample(enabled: false));
      expect(look(tester), (c.surfaceRaised, c.borderSubtle, c.textDisabled));
      expect(textColor(tester, 'iPhone 15'), c.textDisabled);
      expect(textColor(tester, '852×393'), c.textDisabled);
    });

    testWidgets('click and keyboard', (tester) async {
      var presses = 0;
      await pumpFs(tester, sample(onPressed: () => presses++));
      await tester.tap(chip);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        tester.widget<FsFocusRing>(find.byType(FsFocusRing)).visible,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(presses, 2);
    });
  });
}
