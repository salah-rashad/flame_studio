import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

const _save = FsDialog<String>(
  title: 'Save changes to level_1.scene?',
  body: 'You have 3 unsaved changes.',
  primary: FsDialogAction(label: 'Save', value: 'save'),
  secondary: FsDialogAction(label: 'Cancel', value: 'cancel'),
  destructive: FsDialogAction(label: "Don't save", value: 'discard'),
  closeTooltip: 'Close',
);

/// Pumps a trigger button that opens [dialog] and records the answer.
Future<List<String?>> _pumpTrigger(
  WidgetTester tester, [
  FsDialog<String> dialog = _save,
]) async {
  final answers = <String?>[];
  await pumpFs(
    tester,
    Builder(
      builder: (context) => FsButton(
        label: 'Open',
        onPressed: () async =>
            answers.add(await showFsDialog(context, dialog: dialog)),
      ),
    ),
    width: 200,
  );
  return answers;
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

FocusNode? get _focus => FocusManager.instance.primaryFocus;

/// Whether keyboard focus is on the button labelled [label].
bool _focused(String label) =>
    _focus?.context?.findAncestorWidgetOfExactType<FsButton>()?.label == label;

void main() {
  testWidgets('440 wide, overlay surface, radius-lg, dialog shadow', (
    tester,
  ) async {
    await _pumpTrigger(tester);
    await _open(tester);
    final dialog = find.byType(FsDialog<String>);
    expect(tester.getSize(dialog).width, 440);
    final box = decorationIn(tester, dialog);
    expect(box.color, c.surfaceOverlay);
    expect((box.border! as Border).top.color, c.borderOverlay);
    expect(box.borderRadius, FsRadii.lg);
    expect(box.boxShadow, FsShadows.dark.dialog);
    expect(textColor(tester, 'Save changes to level_1.scene?'), c.textPrimary);
    expect(
      tester
          .widget<Text>(find.text('Save changes to level_1.scene?'))
          .style!
          .fontSize,
      FsText.title.fontSize,
    );
    expect(textColor(tester, 'You have 3 unsaved changes.'), c.textSecondary);
    // Centred over the scrim.
    expect(tester.getCenter(dialog), const Offset(400, 300));
    final barrier = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
    expect(barrier.color, c.scrim);
  });

  testWidgets('form width is 560', (tester) async {
    await _pumpTrigger(
      tester,
      const FsDialog(
        title: 'New scene',
        primary: FsDialogAction(label: 'Create', value: 'create'),
        width: FsDialogWidth.form,
      ),
    );
    await _open(tester);
    expect(tester.getSize(find.byType(FsDialog<String>)).width, 560);
  });

  testWidgets('destructive left and apart; Cancel and primary right', (
    tester,
  ) async {
    await _pumpTrigger(tester);
    await _open(tester);
    final discard = tester.getRect(find.text("Don't save"));
    final cancel = tester.getRect(find.text('Cancel'));
    final save = tester.getRect(find.text('Save'));
    expect(discard.left, lessThan(cancel.left - 100));
    expect(cancel.right, lessThan(save.left));
    final variants = {
      for (final b in tester.widgetList<FsButton>(find.byType(FsButton)))
        b.label: b.variant,
    };
    expect(variants["Don't save"], FsButtonVariant.danger);
    expect(variants['Cancel'], FsButtonVariant.secondary);
    expect(variants['Save'], FsButtonVariant.primary);
  });

  for (final (name, label, value) in [
    ('primary', 'Save', 'save'),
    ('secondary', 'Cancel', 'cancel'),
    ('destructive', "Don't save", 'discard'),
  ]) {
    testWidgets('clicking $name returns its value', (tester) async {
      final answers = await _pumpTrigger(tester);
      await _open(tester);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(answers, [value]);
      expect(find.byType(FsDialog<String>), findsNothing);
    });
  }

  testWidgets('the close × answers the secondary value', (tester) async {
    final answers = await _pumpTrigger(tester);
    await _open(tester);
    await tester.tap(find.byIcon(FsIcons.x));
    await tester.pumpAndSettle();
    expect(answers, ['cancel']);
  });

  testWidgets('primary has initial focus and answers Enter', (tester) async {
    final answers = await _pumpTrigger(tester);
    await _open(tester);
    expect(_focused('Save'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(answers, ['save']);
  });

  testWidgets('Esc answers the secondary value, or null without one', (
    tester,
  ) async {
    final answers = await _pumpTrigger(tester);
    await _open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(answers, ['cancel']);

    final bare = await _pumpTrigger(
      tester,
      const FsDialog(
        title: 'Done',
        primary: FsDialogAction(label: 'OK', value: 'ok'),
      ),
    );
    await _open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(bare, [null]);
  });

  testWidgets('Enter on a focused secondary button answers that button', (
    tester,
  ) async {
    final answers = await _pumpTrigger(tester);
    await _open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab, platform: 'macos');
    await tester.pump();
    // Tab from the primary wraps to the first control: the close ×.
    expect(
      _focus?.context?.findAncestorWidgetOfExactType<FsIconButton>()?.icon,
      FsIcons.x,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_focused("Don't save"), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_focused('Cancel'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(answers, ['cancel']);
  });

  testWidgets('focus is trapped: Shift+Tab from the first control wraps', (
    tester,
  ) async {
    await _pumpTrigger(tester);
    await _open(tester);
    for (var i = 0; i < 8; i++) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(FsDialog<String>),
          matching: find.byWidgetPredicate(
            (w) => w is Focus && w.focusNode == _focus,
          ),
        ),
        findsOneWidget,
        reason: 'step $i',
      );
    }
  });

  testWidgets('focus returns to the trigger on close', (tester) async {
    await _pumpTrigger(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_focused('Open'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_focused('Save'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_focused('Open'), isTrue);
  });

  testWidgets('Enter in a form field answers the primary', (tester) async {
    final answers = await _pumpTrigger(
      tester,
      const FsDialog(
        title: 'New scene',
        content: FsTextField(value: 'level_2', autofocus: true),
        primary: FsDialogAction(label: 'Create', value: 'create'),
        secondary: FsDialogAction(label: 'Cancel', value: 'cancel'),
        width: FsDialogWidth.form,
      ),
    );
    await _open(tester);
    expect(
      _focus?.context?.findAncestorWidgetOfExactType<EditableText>(),
      isNotNull,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(answers, ['create']);
  });

  testWidgets('content text defaults to text-primary', (tester) async {
    await _pumpTrigger(
      tester,
      const FsDialog(
        title: 'Close',
        body: 'Body',
        content: Text('Always save when closing scenes'),
        primary: FsDialogAction(label: 'OK'),
      ),
    );
    await _open(tester);
    final style = DefaultTextStyle.of(
      tester.element(find.text('Always save when closing scenes')),
    ).style;
    expect(style.color, c.textPrimary);
  });

  testWidgets('a 200ms fade, no scale', (tester) async {
    await _pumpTrigger(tester);
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final fade = tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.byType(FsDialog<String>),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(fade.opacity.value, closeTo(Curves.easeOut.transform(0.5), 1e-6));
    expect(
      find.ancestor(
        of: find.byType(FsDialog<String>),
        matching: find.byType(ScaleTransition),
      ),
      findsNothing,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(fade.opacity.value, 1);
    await tester.pumpAndSettle();
  });

  testWidgets('the scrim does not close it', (tester) async {
    final answers = await _pumpTrigger(tester);
    await _open(tester);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(FsDialog<String>), findsOneWidget);
    expect(answers, isEmpty);
  });

  testWidgets('forced parts reach one button each', (tester) async {
    await pumpFs(
      tester,
      const FsDebugStates(
        states: {WidgetState.focused},
        part: 'primary',
        child: ExcludeFocus(child: _save),
      ),
      width: 600,
    );
    bool ring(String label) => tester
        .widgetList<FsFocusRing>(
          find.descendant(
            of: find.widgetWithText(FsButton, label),
            matching: find.byType(FsFocusRing),
          ),
        )
        .single
        .visible;
    expect(ring('Save'), isTrue);
    expect(ring('Cancel'), isFalse);
    expect(ring("Don't save"), isFalse);
  });

  testWidgets('drawn inline, a button leaves the first route alone', (
    tester,
  ) async {
    await pumpFs(tester, const ExcludeFocus(child: _save), width: 600);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(FsDialog<String>), findsOneWidget);
  });
}
