import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../helpers.dart';

const _save = PrDialog<String>(
  title: 'Save changes to level_1.scene?',
  body: 'You have 3 unsaved changes.',
  primary: PrDialogAction(label: 'Save', value: 'save'),
  secondary: PrDialogAction(label: 'Cancel', value: 'cancel'),
  destructive: PrDialogAction(label: "Don't save", value: 'discard'),
  closeTooltip: 'Close',
);

/// Pumps a trigger button that opens [dialog] and records the answer.
Future<List<String?>> _pumpTrigger(
  WidgetTester tester, [
  PrDialog<String> dialog = _save,
  bool barrierDismissible = false,
]) async {
  final answers = <String?>[];
  await pumpFs(
    tester,
    Builder(
      builder: (context) => PrButton(
        label: 'Open',
        onPressed: () async => answers.add(
          await showFsDialog(
            context,
            dialog: dialog,
            barrierDismissible: barrierDismissible,
          ),
        ),
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
    _focus?.context?.findAncestorWidgetOfExactType<PrButton>()?.label == label;

void main() {
  testWidgets('440 wide, overlay surface, radius-lg, dialog shadow', (
    tester,
  ) async {
    await _pumpTrigger(tester);
    await _open(tester);
    final dialog = find.byType(PrDialog<String>);
    expect(tester.getSize(dialog).width, 440);
    final box = decorationIn(tester, dialog);
    expect(box.color, c.surfaceOverlay);
    expect((box.border! as Border).top.color, c.borderOverlay);
    expect(box.borderRadius, PrRadii.lg);
    expect(box.boxShadow, PrShadows.dark.dialog);
    expect(textColor(tester, 'Save changes to level_1.scene?'), c.textPrimary);
    expect(
      tester
          .widget<Text>(find.text('Save changes to level_1.scene?'))
          .style!
          .fontSize,
      PrText.title.fontSize,
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
      const PrDialog(
        title: 'New scene',
        primary: PrDialogAction(label: 'Create', value: 'create'),
        width: PrDialogWidth.form,
      ),
    );
    await _open(tester);
    expect(tester.getSize(find.byType(PrDialog<String>)).width, 560);
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
      for (final b in tester.widgetList<PrButton>(find.byType(PrButton)))
        b.label: b.variant,
    };
    expect(variants["Don't save"], PrButtonVariant.danger);
    expect(variants['Cancel'], PrButtonVariant.secondary);
    expect(variants['Save'], PrButtonVariant.primary);
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
      expect(find.byType(PrDialog<String>), findsNothing);
    });
  }

  testWidgets('the close × answers the secondary value', (tester) async {
    final answers = await _pumpTrigger(tester);
    await _open(tester);
    await tester.tap(find.byIcon(PrIcons.x));
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
      const PrDialog(
        title: 'Done',
        primary: PrDialogAction(label: 'OK', value: 'ok'),
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
      _focus?.context?.findAncestorWidgetOfExactType<PrIconButton>()?.icon,
      PrIcons.x,
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
          of: find.byType(PrDialog<String>),
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
      const PrDialog(
        title: 'New scene',
        content: PrTextField(value: 'level_2', autofocus: true),
        primary: PrDialogAction(label: 'Create', value: 'create'),
        secondary: PrDialogAction(label: 'Cancel', value: 'cancel'),
        width: PrDialogWidth.form,
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
      const PrDialog(
        title: 'Close',
        body: 'Body',
        content: Text('Always save when closing scenes'),
        primary: PrDialogAction(label: 'OK'),
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
            of: find.byType(PrDialog<String>),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(fade.opacity.value, closeTo(Curves.easeOut.transform(0.5), 1e-6));
    expect(
      find.ancestor(
        of: find.byType(PrDialog<String>),
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
    expect(find.byType(PrDialog<String>), findsOneWidget);
    expect(answers, isEmpty);
  });

  testWidgets('barrierDismissible: the scrim answers like Esc', (tester) async {
    final answers = await _pumpTrigger(tester, _save, true);
    await _open(tester);
    // A click on the dialog itself doesn't count.
    await tester.tapAt(
      tester.getTopLeft(find.byType(PrDialog<String>)) + const Offset(30, 60),
    );
    await tester.pumpAndSettle();
    expect(answers, isEmpty);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(answers, ['cancel']);
    expect(find.byType(PrDialog<String>), findsNothing);

    final bare = await _pumpTrigger(
      tester,
      const PrDialog(
        title: 'Done',
        primary: PrDialogAction(label: 'OK', value: 'ok'),
      ),
      true,
    );
    await _open(tester);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(bare, [null]);
  });

  testWidgets('text in the route gets the theme style, no debug underline', (
    tester,
  ) async {
    await _pumpTrigger(tester);
    await _open(tester);
    for (final text in [
      'Save changes to level_1.scene?',
      'You have 3 unsaved changes.',
      'Save',
      'Cancel',
    ]) {
      final style = DefaultTextStyle.of(tester.element(find.text(text))).style;
      expect(
        style.decoration ?? TextDecoration.none,
        TextDecoration.none,
        reason: text,
      );
      expect(style.fontFamily, PrText.body.fontFamily, reason: text);
      // What the Text widget actually paints.
      final painted = tester
          .renderObject<RenderParagraph>(
            find.descendant(
              of: find.text(text),
              matching: find.byType(RichText),
            ),
          )
          .text
          .style!;
      expect(
        painted.decoration ?? TextDecoration.none,
        TextDecoration.none,
        reason: text,
      );
    }
  });

  testWidgets('forced parts reach one button each', (tester) async {
    await pumpFs(
      tester,
      const PrDebugStates(
        states: {WidgetState.focused},
        part: 'primary',
        child: ExcludeFocus(child: _save),
      ),
      width: 600,
    );
    bool ring(String label) => tester
        .widgetList<PrFocusRing>(
          find.descendant(
            of: find.widgetWithText(PrButton, label),
            matching: find.byType(PrFocusRing),
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
    expect(find.byType(PrDialog<String>), findsOneWidget);
  });
}
