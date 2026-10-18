import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../helpers.dart';

enum _Anchor { topLeft, topCenter, center, centerRight, bottomCenter }

List<PrDropdownOption<_Anchor>> get _anchors => [
  for (final a in _Anchor.values)
    PrDropdownOption(value: a, label: a.name, detail: 'Anchor.${a.name}'),
];

Widget _dropdown({
  _Anchor? value = _Anchor.center,
  bool mixed = false,
  bool enabled = true,
  String? errorText,
  Set<WidgetState> forced = const {},
  ValueChanged<_Anchor>? onChanged,
  bool mono = true,
}) {
  final Widget dropdown = PrDropdown<_Anchor>(
    options: _anchors,
    value: value,
    mixed: mixed,
    monoOptions: mono,
    errorText: errorText,
    onChanged: enabled ? (onChanged ?? (_) {}) : null,
  );
  return Align(
    alignment: Alignment.topLeft,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: 220,
        child: forced.isEmpty
            ? dropdown
            : PrDebugStates(states: forced, child: dropdown),
      ),
    ),
  );
}

final _field = find.byType(PrFieldBox);
final _list = find.text('Anchor.topLeft');

Future<void> _click(WidgetTester tester, Finder finder) async {
  final gesture = await tester.startGesture(
    tester.getCenter(finder),
    kind: PointerDeviceKind.mouse,
  );
  await gesture.up();
  await gesture.removePointer();
  await tester.pumpAndSettle();
}

/// The fill of the list item showing [text].
Color? _itemFill(WidgetTester tester, String text) {
  final item = tester.widget<Container>(
    find.ancestor(of: find.text(text), matching: find.byType(Container)).first,
  );
  return (item.decoration! as BoxDecoration).color;
}

void main() {
  testWidgets('field: label and chevron; states', (tester) async {
    await pumpFs(tester, _dropdown());
    expect(find.text('center'), findsOneWidget);
    expect(find.byIcon(PrIcons.chevronDown), findsOneWidget);
    expect(tester.getSize(_field).height, 24);
    expect(fieldBorder(tester, _field), c.borderControl);
    expect(textColor(tester, 'center'), c.textPrimary);

    await pumpFs(tester, _dropdown(forced: {WidgetState.hovered}));
    expect(fieldBorder(tester, _field), c.borderStrong);
    await pumpFs(tester, _dropdown(forced: {WidgetState.pressed}));
    expect(fieldFill(tester, _field), c.surfaceHover);
    await pumpFs(tester, _dropdown(forced: {WidgetState.focused}));
    expect(fieldBorder(tester, _field), c.focusRing);
    await pumpFs(tester, _dropdown(errorText: 'Unknown anchor'));
    expect(fieldBorder(tester, _field), c.error);
    await pumpFs(tester, _dropdown(enabled: false));
    expect(fieldFill(tester, _field), c.surfacePanel);
    expect(textColor(tester, 'center'), c.textDisabled);
    await pumpFs(tester, _dropdown(mixed: true));
    expect(find.text('—'), findsOneWidget);
    expect(textColor(tester, '—'), c.textSecondary);
  });

  testWidgets('click opens the list on the current value, as wide as the '
      'field; a click on an item chooses it', (tester) async {
    final values = <_Anchor>[];
    await pumpFs(tester, _dropdown(onChanged: values.add));
    await _click(tester, _field);
    expect(_list, findsOneWidget);
    // The focus treatment while open, for clicks too.
    expect(fieldBorder(tester, _field), c.focusRing);
    final list = find.ancestor(
      of: _list,
      matching: find.byType(SingleChildScrollView),
    );
    // The scroll view sits inside the list's 1px border.
    expect(tester.getSize(list).width, 220 - 2);
    expect(tester.getTopLeft(list).dy, tester.getBottomLeft(_field).dy + 4 + 1);
    // Mono Dart names; the current value has the check and the highlight.
    expect(
      tester.widget<Text>(find.text('Anchor.center')).style!.fontFamily,
      contains('JetBrains Mono'),
    );
    expect(_itemFill(tester, 'Anchor.center'), c.accent);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Anchor.center'),
          matching: find.byType(Row),
        ),
        matching: find.byIcon(PrIcons.check),
      ),
      findsOneWidget,
    );

    await _click(tester, find.text('Anchor.topCenter'));
    expect(_list, findsNothing);
    expect(values, [_Anchor.topCenter]);
  });

  testWidgets('hovering an item highlights it', (tester) async {
    await pumpFs(tester, _dropdown());
    await _click(tester, _field);
    final m = await mouse(tester);
    await hover(tester, m, find.text('Anchor.bottomCenter'));
    expect(_itemFill(tester, 'Anchor.bottomCenter'), c.accent);
    expect(_itemFill(tester, 'Anchor.center'), Colors.transparent);
  });

  testWidgets('keyboard: ↓ opens, ↓ moves, Enter chooses; Esc closes '
      'without a change', (tester) async {
    final values = <_Anchor>[];
    await pumpFs(tester, _dropdown(onChanged: values.add));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_list, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_itemFill(tester, 'Anchor.centerRight'), c.accent);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_list, findsNothing);
    expect(values, [_Anchor.centerRight]);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(_list, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_list, findsNothing);
    expect(values, [_Anchor.centerRight]);
  });

  testWidgets('choosing the current value reports nothing', (tester) async {
    final values = <_Anchor>[];
    await pumpFs(tester, _dropdown(onChanged: values.add));
    await _click(tester, _field);
    await _click(tester, find.text('Anchor.center'));
    expect(values, isEmpty);
  });

  testWidgets('type-ahead jumps to a match, open or closed', (tester) async {
    final values = <_Anchor>[];
    await pumpFs(tester, _dropdown(onChanged: values.add));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    // Closed: "b" opens the list on bottomCenter.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.pumpAndSettle();
    expect(_itemFill(tester, 'Anchor.bottomCenter'), c.accent);
    // Typed text resets after a second.
    await tester.pump(const Duration(seconds: 1));
    // Open: "t" then "t" step through the options starting with t.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.pump();
    expect(_itemFill(tester, 'Anchor.topLeft'), c.accent);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.pump();
    expect(_itemFill(tester, 'Anchor.topCenter'), c.accent);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(values, [_Anchor.topCenter]);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('an outside click closes it without a change', (tester) async {
    final values = <_Anchor>[];
    await pumpFs(tester, _dropdown(onChanged: values.add));
    await _click(tester, _field);
    await tester.tapAt(const Offset(500, 500));
    await tester.pumpAndSettle();
    expect(_list, findsNothing);
    expect(values, isEmpty);
  });

  testWidgets('mixed: choosing any value reports it', (tester) async {
    final values = <_Anchor>[];
    await pumpFs(tester, _dropdown(mixed: true, onChanged: values.add));
    await _click(tester, _field);
    expect(find.byIcon(PrIcons.check), findsNothing);
    await _click(tester, find.text('Anchor.center'));
    expect(values, [_Anchor.center]);
  });

  testWidgets('disabled: no list', (tester) async {
    await pumpFs(tester, _dropdown(enabled: false));
    await _click(tester, _field);
    expect(_list, findsNothing);
  });

  testWidgets('labels, not Dart names, without monoOptions', (tester) async {
    await pumpFs(tester, _dropdown(mono: false));
    await _click(tester, _field);
    expect(find.text('topLeft'), findsOneWidget);
    expect(_list, findsNothing);
  });

  testWidgets('inside a property row: dense, follows the row', (tester) async {
    await pumpFs(
      tester,
      PrPropertyRow(
        label: 'anchor',
        editor: PrDropdown<_Anchor>(
          options: _anchors,
          value: _Anchor.center,
          size: PrFieldSize.dense,
          onChanged: (_) {},
        ),
      ),
    );
    expect(tester.getSize(_field).height, 20);
    // Default from code: the value in text-secondary.
    expect(textColor(tester, 'center'), c.textSecondary);
  });
}
