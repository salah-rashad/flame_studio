import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

final _empty = find.byType(FsEmptyState);

Future<void> _pump(
  WidgetTester tester, {
  String message = 'Open a scene from Assets, or start a new one.',
  String? hint,
  VoidCallback? onPressed,
}) => pumpFs(
  tester,
  SizedBox(
    height: 400,
    child: Center(
      child: FsEmptyState(
        icon: FsIcons.layers,
        title: 'No scene open',
        message: message,
        action: FsButton(
          label: 'New scene',
          icon: FsIcons.plus,
          variant: FsButtonVariant.primary,
          onPressed: onPressed ?? () {},
        ),
        shortcutHint: hint,
      ),
    ),
  ),
  width: 600,
);

void main() {
  testWidgets('a 48px raised tile with a 24px secondary icon', (tester) async {
    await _pump(tester);
    final tile = find.ancestor(
      of: find.byIcon(FsIcons.layers),
      matching: find.byType(Container),
    );
    expect(tester.getSize(tile.first), const Size.square(48));
    final box = decorationIn(tester, _empty);
    expect(box.color, c.surfaceRaised);
    expect((box.border! as Border).top.color, c.borderSubtle);
    expect(box.borderRadius, FsRadii.lg);
    final icon = tester.widget<Icon>(find.byIcon(FsIcons.layers));
    expect(icon.size, 24);
    expect(icon.color, c.textSecondary);
  });

  testWidgets('title, message and button are centred in a column', (
    tester,
  ) async {
    await _pump(tester);
    final centre = tester.getCenter(_empty).dx;
    for (final f in [
      find.byIcon(FsIcons.layers),
      find.text('No scene open'),
      find.text('Open a scene from Assets, or start a new one.'),
      find.byType(FsButton),
    ]) {
      expect(tester.getCenter(f).dx, closeTo(centre, 0.5));
    }
    expect(textColor(tester, 'No scene open'), c.textPrimary);
    expect(
      tester.widget<Text>(find.text('No scene open')).style!.fontSize,
      FsText.title.fontSize,
    );
    expect(
      textColor(tester, 'Open a scene from Assets, or start a new one.'),
      c.textSecondary,
    );
    // Gaps: tile → title 16, title → message 8, message → button 16.
    final tile = tester.getRect(find.byIcon(FsIcons.layers)).inflate(12);
    final title = tester.getRect(find.text('No scene open'));
    final message = tester.getRect(
      find.text('Open a scene from Assets, or start a new one.'),
    );
    final button = tester.getRect(find.byType(FsButton));
    expect(title.top - tile.bottom, 16);
    expect(message.top - title.bottom, 8);
    expect(button.top - message.bottom, 16);
    // 24px padding around it all.
    expect(tile.top - tester.getRect(_empty).top, 24);
  });

  testWidgets('the message wraps at 280px', (tester) async {
    await _pump(
      tester,
      message:
          'Check the spelling or search by component type, for example '
          't:SpriteComponent, or clear the search to see every node.',
    );
    final message = find.textContaining('Check the spelling');
    expect(tester.getSize(message).width, lessThanOrEqualTo(280));
    expect(tester.getSize(message).height, greaterThan(16));
  });

  testWidgets('the action is the caller\'s button', (tester) async {
    var pressed = 0;
    await _pump(tester, onPressed: () => pressed++);
    await tester.tap(find.text('New scene'));
    expect(pressed, 1);
  });

  testWidgets('shortcut hint: 11px text-secondary, 12px under the button', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('or press ⌘N'), findsNothing);
    await _pump(tester, hint: 'or press ⌘N');
    final style = tester.widget<Text>(find.text('or press ⌘N')).style!;
    expect(style.fontSize, 11);
    expect(style.color, c.textSecondary);
    expect(
      tester.getTopLeft(find.text('or press ⌘N')).dy -
          tester.getBottomLeft(find.byType(FsButton)).dy,
      12,
    );
  });
}
