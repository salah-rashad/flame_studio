import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

final _field = find.byType(FsTextField);
final _editable = find.byType(EditableText);

String? _names(String text) => RegExp(r'^[A-Za-z0-9_]*$').hasMatch(text)
    ? null
    : 'Names may only use letters, digits and _';

void main() {
  testWidgets('24px, dense 20px; surface-input, border-control', (
    tester,
  ) async {
    await pumpFs(tester, const FsTextField(value: 'PlayerController'));
    expect(tester.getSize(find.byType(FsFieldBox)).height, 24);
    expect(fieldFill(tester, _field), c.surfaceInput);
    expect(fieldBorder(tester, _field), c.borderControl);
    expect(fieldTextColor(tester), c.textPrimary);
    await pumpFs(
      tester,
      const FsTextField(value: 'Hero', size: FsFieldSize.dense),
    );
    expect(tester.getSize(find.byType(FsFieldBox)).height, 20);
  });

  testWidgets('placeholder while empty, in text-placeholder', (tester) async {
    await pumpFs(tester, const FsTextField(placeholder: 'Node name'));
    final placeholder = find.text('Node name');
    expect(textColor(tester, 'Node name'), c.textPlaceholder);
    expect(
      tester
          .widget<Visibility>(
            find.ancestor(of: placeholder, matching: find.byType(Visibility)),
          )
          .visible,
      isTrue,
    );
    await tester.enterText(_editable, 'Hero');
    await tester.pump();
    expect(placeholder, findsNothing);
  });

  testWidgets('hover border-strong; click focuses with the focus ring', (
    tester,
  ) async {
    await pumpFs(tester, const FsTextField(value: 'Hero'));
    final m = await mouse(tester);
    await hover(tester, m, _field);
    expect(fieldBorder(tester, _field), c.borderStrong);
    await tester.tap(_field);
    await tester.pump();
    expect(fieldBorder(tester, _field), c.focusRing);
  });

  testWidgets('onChanged per edit, onSubmitted on Enter', (tester) async {
    final changes = <String>[];
    final submits = <String>[];
    await pumpFs(
      tester,
      FsTextField(
        value: 'Hero',
        onChanged: changes.add,
        onSubmitted: submits.add,
      ),
    );
    await tester.tap(_field);
    await tester.enterText(_editable, 'Player');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(changes, ['Player']);
    expect(submits, ['Player']);
  });

  testWidgets('error: border, alert icon, message below; focus kept', (
    tester,
  ) async {
    await pumpFs(tester, const FsTextField(value: 'Player', validator: _names));
    expect(find.byIcon(FsIcons.alertCircle), findsNothing);
    await tester.tap(_field);
    await tester.pump();
    await tester.enterText(_editable, 'Player 1!');
    await tester.pump();
    expect(fieldBorder(tester, _field), c.error);
    expect(find.byIcon(FsIcons.alertCircle), findsOneWidget);
    expect(
      textColor(tester, 'Names may only use letters, digits and _'),
      c.error,
    );
    // The editor survived the message appearing.
    final editable = tester.widget<EditableText>(_editable);
    expect(editable.focusNode.hasFocus, isTrue);
    expect(editable.controller.text, 'Player 1!');
  });

  testWidgets('an invalid starting value shows the error at once', (
    tester,
  ) async {
    await pumpFs(tester, const FsTextField(value: 'a b', validator: _names));
    expect(fieldBorder(tester, _field), c.error);
  });

  testWidgets('dense rows: the message goes in a tooltip', (tester) async {
    await pumpFs(
      tester,
      const FsTextField(
        value: 'a b',
        validator: _names,
        errorDisplay: FsErrorDisplay.tooltip,
      ),
    );
    expect(find.text('Names may only use letters, digits and _'), findsNothing);
    expect(find.byType(FsTooltip), findsOneWidget);
    expect(
      tester.widget<FsTooltip>(find.byType(FsTooltip)).message,
      'Names may only use letters, digits and _',
    );
  });

  testWidgets('disabled: flat, text-disabled, no focus', (tester) async {
    await pumpFs(tester, const FsTextField(value: 'Hero', enabled: false));
    expect(fieldFill(tester, _field), c.surfacePanel);
    expect(fieldBorder(tester, _field), c.borderSubtle);
    expect(fieldTextColor(tester), c.textDisabled);
    await tester.tap(_field);
    await tester.pump();
    expect(tester.widget<EditableText>(_editable).focusNode.hasFocus, isFalse);
  });

  testWidgets('read-only: flat, text-primary, not editable', (tester) async {
    await pumpFs(tester, const FsTextField(value: 'Hero', readOnly: true));
    expect(fieldFill(tester, _field), c.surfacePanel);
    expect(fieldTextColor(tester), c.textPrimary);
    expect(tester.widget<EditableText>(_editable).readOnly, isTrue);
  });

  testWidgets('mono for paths', (tester) async {
    await pumpFs(
      tester,
      const FsTextField(value: 'lib/game/player.dart', mono: true),
    );
    expect(
      tester.widget<EditableText>(_editable).style.fontFamily,
      FsText.mono.fontFamily,
    );
  });

  testWidgets('a new value shows while not focused, not while typing', (
    tester,
  ) async {
    Widget field(String v) => FsTextField(value: v);
    await pumpFs(tester, field('A'));
    await pumpFs(tester, field('B'));
    expect(fieldText(tester), 'B');
    await tester.tap(_field);
    await tester.enterText(_editable, 'typing');
    await pumpFs(tester, field('C'));
    expect(fieldText(tester), 'typing');
  });

  testWidgets('forced states for the gallery', (tester) async {
    await pumpFs(
      tester,
      const FsDebugStates(
        states: {WidgetState.focused},
        child: FsTextField(value: 'Hero'),
      ),
    );
    expect(fieldBorder(tester, _field), c.focusRing);
  });
}
