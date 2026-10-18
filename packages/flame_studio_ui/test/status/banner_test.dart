import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

final _banner = find.byType(FsBanner);

Widget _sample({
  FsStatusKind kind = FsStatusKind.warning,
  FsBannerAction? action,
  VoidCallback? onDismiss,
}) => Padding(
  padding: const EdgeInsets.all(20),
  child: FsBanner(
    kind: kind,
    message: const TextSpan(
      children: [
        TextSpan(
          text: '2 overrides',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        TextSpan(text: ' differ from the prefab.'),
      ],
    ),
    action: action,
    onDismiss: onDismiss,
    dismissTooltip: 'Dismiss',
  ),
);

void main() {
  for (final (kind, fill, edge, ink, icon) in [
    (FsStatusKind.info, c.infoSubtle, c.infoBorder, c.info, FsIcons.info),
    (
      FsStatusKind.warning,
      c.warningSubtle,
      c.warningBorder,
      c.warning,
      FsIcons.alertTriangle,
    ),
    (
      FsStatusKind.error,
      c.errorSubtle,
      c.errorBorder,
      c.error,
      FsIcons.alertCircle,
    ),
    (
      FsStatusKind.success,
      c.successSubtle,
      c.successBorder,
      c.success,
      FsIcons.checkCircle,
    ),
  ]) {
    testWidgets('${kind.name}: subtle fill, border edge, its icon', (
      tester,
    ) async {
      await pumpFs(tester, _sample(kind: kind));
      final box = decorationIn(tester, _banner);
      expect(box.color, fill);
      expect((box.border! as Border).top.color, edge);
      expect(box.borderRadius, FsRadii.sm);
      final glyph = tester.widget<Icon>(find.byIcon(icon));
      expect(glyph.color, ink);
      expect(glyph.size, 16);
    });
  }

  testWidgets('message: small text-primary, the subject bold', (tester) async {
    await pumpFs(tester, _sample());
    // The last RichText; the first is the icon's glyph.
    final text = tester.widget<RichText>(
      find.descendant(of: _banner, matching: find.byType(RichText)).last,
    );
    final span = text.text as TextSpan;
    expect(span.style!.color, c.textPrimary);
    expect(span.style!.fontSize, FsText.small.fontSize);
    expect(span.toPlainText(), contains('2 overrides differ from the prefab.'));
    final subject = (span.children!.single as TextSpan).children!.first;
    expect(subject.style!.fontWeight, FontWeight.w600);
  });

  testWidgets('no controls: 8px padding inside the 1px edge', (tester) async {
    await pumpFs(tester, _sample());
    expect(tester.getSize(_banner).height, 1 + 8 + 16 + 8 + 1);
    expect(
      tester.getTopLeft(find.byType(Icon)) - tester.getTopLeft(_banner),
      const Offset(9, 9),
    );
  });

  testWidgets('action: a 20px ghost button reaching 2px into the padding', (
    tester,
  ) async {
    final log = <String>[];
    await pumpFs(
      tester,
      _sample(
        action: FsBannerAction(
          label: 'Review',
          onPressed: () => log.add('review'),
        ),
        onDismiss: () => log.add('dismiss'),
      ),
      width: 500,
    );
    // Same height as without controls.
    expect(tester.getSize(_banner).height, 34);
    final button = find.widgetWithText(FsButton, 'Review');
    expect(tester.widget<FsButton>(button).variant, FsButtonVariant.ghost);
    expect(tester.getSize(button).height, 20);
    expect(textColor(tester, 'Review'), c.textPrimary);
    final dismiss = find.byType(FsIconButton);
    expect(tester.getSize(dismiss), const Size.square(20));
    expect(
      tester.getTopRight(_banner).dx - tester.getTopRight(dismiss).dx,
      1 + 6,
    );
    expect(tester.getTopLeft(dismiss).dx - tester.getTopRight(button).dx, 2);
    await tester.tap(button);
    await tester.tap(dismiss);
    expect(log, ['review', 'dismiss']);
  });

  testWidgets('controls draw text-primary and a white wash on hover', (
    tester,
  ) async {
    await pumpFs(
      tester,
      FsDebugStates(
        part: 'dismiss',
        states: const {WidgetState.hovered},
        child: _sample(
          action: FsBannerAction(label: 'Review', onPressed: () {}),
          onDismiss: () {},
        ),
      ),
    );
    final dismiss = find.byType(FsIconButton);
    expect(
      decorationIn(tester, dismiss).color,
      c.textPrimary.withValues(alpha: 0.08),
    );
    expect(tester.widget<Icon>(find.byIcon(FsIcons.x)).color, c.textPrimary);
    // The part reaches the × only.
    expect(
      decorationIn(tester, find.byType(FsButton)).color,
      Colors.transparent,
    );
  });

  testWidgets('forcing the action part presses only the action', (
    tester,
  ) async {
    await pumpFs(
      tester,
      FsDebugStates(
        part: 'action',
        states: const {WidgetState.pressed},
        child: _sample(
          action: FsBannerAction(label: 'Review', onPressed: () {}),
          onDismiss: () {},
        ),
      ),
    );
    expect(
      decorationIn(tester, find.byType(FsButton)).color,
      c.textPrimary.withValues(alpha: 0.12),
    );
    expect(
      decorationIn(tester, find.byType(FsIconButton)).color,
      Colors.transparent,
    );
  });

  testWidgets('a disabled action keeps the ghost disabled look', (
    tester,
  ) async {
    await pumpFs(
      tester,
      _sample(action: const FsBannerAction(label: 'Review', onPressed: null)),
    );
    expect(textColor(tester, 'Review'), c.textDisabled);
  });
}
