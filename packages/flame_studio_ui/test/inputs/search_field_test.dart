import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

Widget _search({
  String query = '',
  bool noMatch = false,
  bool enabled = true,
  Set<WidgetState> forced = const {},
  ValueChanged<String>? onChanged,
  VoidCallback? onExit,
  VoidCallback? onNext,
  VoidCallback? onPrevious,
}) {
  final Widget field = FsSearchField(
    query: query,
    placeholder: 'Search nodes',
    resultLabel: '3 of 12',
    noMatch: noMatch,
    noMatchLabel: 'No match',
    shortcutHint: const SingleActivator(LogicalKeyboardKey.keyF, meta: true),
    clearTooltip: 'Clear',
    enabled: enabled,
    onChanged: onChanged ?? (_) {},
    onExit: onExit,
    onNext: onNext,
    onPrevious: onPrevious,
  );
  return SizedBox(
    width: 240,
    child: forced.isEmpty ? field : FsDebugStates(states: forced, child: field),
  );
}

final _field = find.byType(FsFieldBox);

/// A controlled field: the query lives in the test, like in an app.
class _Host extends StatefulWidget {
  const _Host({required this.log, this.onExit});

  final List<String> log;
  final VoidCallback? onExit;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String _query = 'slime';

  @override
  Widget build(BuildContext context) => _search(
    query: _query,
    onExit: widget.onExit,
    onChanged: (q) => setState(() {
      widget.log.add(q);
      _query = q;
    }),
  );
}

void main() {
  testWidgets('empty: icon, placeholder and shortcut hint', (tester) async {
    await pumpFs(tester, _search());
    expect(find.byIcon(FsIcons.search), findsOneWidget);
    expect(textColor(tester, 'Search nodes'), c.textPlaceholder);
    expect(find.byType(FsShortcutLabel), findsOneWidget);
    expect(find.text('3 of 12'), findsNothing);
    expect(find.byIcon(FsIcons.x), findsNothing);
    expect(fieldBorder(tester, _field), c.borderControl);
  });

  testWidgets('with a query: count in mono and the clear button', (
    tester,
  ) async {
    await pumpFs(tester, _search(query: 'slime'));
    expect(fieldText(tester), 'slime');
    expect(find.byType(FsShortcutLabel), findsNothing);
    final count = tester.widget<Text>(find.text('3 of 12')).style!;
    expect(count.fontFamily, contains('JetBrains Mono'));
    expect(count.fontSize, 11);
    expect(count.color, c.textSecondary);
    expect(find.byIcon(FsIcons.x), findsOneWidget);
  });

  testWidgets('no match: error border and label', (tester) async {
    await pumpFs(tester, _search(query: 'slime', noMatch: true));
    expect(fieldBorder(tester, _field), c.error);
    expect(textColor(tester, 'No match'), c.error);
    expect(find.text('3 of 12'), findsNothing);
  });

  testWidgets('hover, focus and disabled', (tester) async {
    await pumpFs(tester, _search(forced: {WidgetState.hovered}));
    expect(fieldBorder(tester, _field), c.borderStrong);
    await pumpFs(tester, _search());
    await tester.tap(_field);
    await tester.pump();
    expect(fieldBorder(tester, _field), c.focusRing); // clicks too
    await pumpFs(tester, _search(query: 'slime', enabled: false));
    expect(fieldFill(tester, _field), c.surfacePanel);
    expect(
      tester.widget<Icon>(find.byIcon(FsIcons.search)).color,
      c.textDisabled,
    );
  });

  testWidgets('typing reports each edit', (tester) async {
    final log = <String>[];
    await pumpFs(tester, _search(onChanged: log.add));
    await tester.tap(_field);
    await tester.enterText(find.byType(EditableText), 'sl');
    await tester.pump();
    expect(log, ['sl']);
  });

  testWidgets('the × clears; Esc clears, a second Esc exits', (tester) async {
    final log = <String>[];
    var exits = 0;
    await pumpFs(tester, _Host(log: log, onExit: () => exits++));
    await tester.tap(find.byIcon(FsIcons.x));
    await tester.pump();
    expect(log, ['']);
    expect(fieldText(tester), '');
    expect(find.byIcon(FsIcons.x), findsNothing);

    await tester.enterText(find.byType(EditableText), 'bat');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(log, ['', 'bat', '']);
    expect(exits, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(exits, 1);
  });

  testWidgets('↓ and ↑ step through results', (tester) async {
    final steps = <int>[];
    await pumpFs(
      tester,
      _search(
        query: 'slime',
        onNext: () => steps.add(1),
        onPrevious: () => steps.add(-1),
      ),
    );
    await tester.tap(_field);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    expect(steps, [1, 1, -1]);
  });

  testWidgets('shows a new query from the app', (tester) async {
    await pumpFs(tester, _search(query: 'slime'));
    await pumpFs(tester, _search(query: 'bat'));
    expect(fieldText(tester), 'bat');
  });
}
