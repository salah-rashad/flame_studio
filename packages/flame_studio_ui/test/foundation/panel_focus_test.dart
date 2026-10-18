import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

final _seen = <String, bool>{};

class _Probe extends StatelessWidget {
  const _Probe(this.name, this.node);

  final String name;
  final FocusNode node;

  @override
  Widget build(BuildContext context) {
    _seen[name] = FsPanelFocus.of(context);
    return Focus(focusNode: node, child: const SizedBox(width: 20, height: 20));
  }
}

void main() {
  testWidgets('true outside any panel', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await pumpFs(tester, _Probe('outside', node));
    expect(_seen['outside'], isTrue);
  });

  setUp(_seen.clear);

  testWidgets('tracks focus anywhere inside the panel', (tester) async {
    final a = FocusNode();
    final b = FocusNode();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await pumpFs(
      tester,
      Column(
        children: [
          FsPanelFocus(child: _Probe('a', a)),
          FsPanelFocus(child: _Probe('b', b)),
        ],
      ),
    );
    expect(_seen, {'a': false, 'b': false});

    a.requestFocus();
    await tester.pump();
    expect(_seen, {'a': true, 'b': false});

    b.requestFocus();
    // Moving focus between scopes settles one frame later.
    await tester.pump();
    await tester.pump();
    expect(_seen, {'a': false, 'b': true});
  });

  testWidgets('Tab leaves the panel instead of looping inside it', (
    tester,
  ) async {
    final a = FocusNode();
    final b = FocusNode();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await pumpFs(
      tester,
      Column(
        children: [
          FsPanelFocus(child: _Probe('a', a)),
          FsPanelFocus(child: _Probe('b', b)),
        ],
      ),
    );
    a.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(b.hasFocus, isTrue);
  });

  testWidgets('Tab skips a panel with nothing focusable inside', (
    tester,
  ) async {
    final a = FocusNode();
    final b = FocusNode();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await pumpFs(
      tester,
      Column(
        children: [
          const FsPanelFocus(child: SizedBox(width: 20, height: 20)),
          _Probe('a', a),
          _Probe('b', b),
        ],
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(a.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(b.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(a.hasFocus, isTrue);
  });

  testWidgets('Tab leaves an empty panel that holds focus', (tester) async {
    final scope = FsPanelFocus.createNode();
    final a = FocusNode();
    addTearDown(scope.dispose);
    addTearDown(a.dispose);
    await pumpFs(
      tester,
      Column(
        children: [
          FsPanelFocus(
            node: scope,
            child: const SizedBox(width: 20, height: 20),
          ),
          _Probe('a', a),
        ],
      ),
    );
    // FsPanel focuses its scope on pointer down.
    scope.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(a.hasFocus, isTrue);

    scope.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pump();
    expect(a.hasFocus, isTrue);
  });

  testWidgets('requesting focus on the panel node returns to its last focus', (
    tester,
  ) async {
    final scope = FsPanelFocus.createNode();
    final a = FocusNode();
    final b = FocusNode();
    addTearDown(scope.dispose);
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await pumpFs(
      tester,
      Column(
        children: [
          FsPanelFocus(node: scope, child: _Probe('a', a)),
          FsPanelFocus(child: _Probe('b', b)),
        ],
      ),
    );
    a.requestFocus();
    await tester.pump();
    b.requestFocus();
    await tester.pump();
    scope.requestFocus();
    await tester.pump();
    expect(a.hasFocus, isTrue);
  });
}
