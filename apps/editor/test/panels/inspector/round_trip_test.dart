import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_runtime/pyro_runtime.dart';
import 'package:pyro_ui/pyro_ui.dart';

import 'harness.dart';

/// The Overrides of node [id] in a saved Scene's JSON.
Map<String, Object?> savedFields(String text, String id) {
  final json = jsonDecode(text) as Map<String, Object?>;
  final nodes = json['nodes']! as Map<String, Object?>;
  return ((nodes[id]! as Map<String, Object?>)['fields'] ?? <String, Object?>{})
      as Map<String, Object?>;
}

void main() {
  testWidgets('the seven editable Field types save and reload exactly '
      '(SC-008)', (tester) async {
    final harness = await openInspector(tester);
    harness.select('hero');
    await tester.pumpAndSettle();

    tester.widget<PrNumberProperty>(numberRow('lives')).onCommit(4);
    tester.widget<PrNumberProperty>(numberRow('speed')).onCommit(6.5);
    tester.widget<PrBoolProperty>(boolRow('flying')).onChanged!(true);
    tester
        .widget<PrTextField>(
          find.descendant(
            of: propertyRow('label'),
            matching: find.byType(PrTextField),
          ),
        )
        .onSubmitted!('Ada');
    tester
        .widget<PrDropdown<String>>(
          find.descendant(
            of: propertyRow('mood'),
            matching: find.byType(PrDropdown<String>),
          ),
        )
        .onChanged!('angry');
    tester.widget<PrVector2Property>(vectorRow('spawn')).onCommit(3, 4);
    tester
        .widget<PrDropdown<String>>(
          find.descendant(
            of: propertyRow('portrait'),
            matching: find.byType(PrDropdown<String>),
          ),
        )
        .onChanged!('assets/images/villain.png');
    await tester.pump();

    final reopened = await harness.saveAndReopen();
    final hero = reopened.state.state.node(const NodeId('hero'))! as CustomNode;
    expect(hero.fields.values, {
      'lives': 4,
      'speed': 6.5,
      'flying': true,
      'label': 'Ada',
      'mood': 'angry',
      'spawn': [3.0, 4.0],
      'portrait': {'asset': 'assets/images/villain.png'},
    });
    // The same bytes the session wrote: nothing else moved.
    expect(savedFields(harness.savedText, 'hero'), hero.fields.values);
    await reopened.discardAndClose();
    await finish(tester, harness);
  });

  testWidgets('read-only fields round-trip untouched while their neighbours '
      'change (SC-008, FR-033)', (tester) async {
    final untouched = <String, Object?>{
      'tint': '#FF112233',
      'buddy': {'node': 'box'},
      'mask': {'asset': 'assets/images/hero.png'},
      'walk': {'asset': 'assets/images/hero.anim.json', 'animation': 'run'},
    };
    final harness = await openInspector(
      tester,
      scene: inspectorScene(heroFields: Overrides(untouched)),
    );
    harness.select('hero');
    await tester.pump();

    tester.widget<PrNumberProperty>(numberRow('lives')).onCommit(2);
    tester.widget<PrNumberProperty>(numberRow('speed')).onCommit(9);
    await tester.pump();

    final reopened = await harness.saveAndReopen();
    final hero = reopened.state.state.node(const NodeId('hero'))! as CustomNode;
    for (final entry in untouched.entries) {
      expect(hero.fields[entry.key], entry.value, reason: entry.key);
    }
    expect(savedFields(harness.savedText, 'hero'), {
      ...untouched,
      'lives': 2,
      'speed': 9,
    });
    await reopened.discardAndClose();
    await finish(tester, harness);
  });

  testWidgets('a Missing type\'s values survive an edit and a save '
      '(constitution IV)', (tester) async {
    final harness = await openInspector(tester);
    harness.select('gone');
    await tester.pump();
    tester.widget<PrVector2Property>(vectorRow('position')).onCommit(1, 2);
    await tester.pump();
    await harness.session.save(runtimeReadsUpTo: 1);
    expect(savedFields(harness.savedText, 'gone'), {'secret': 42});
    await finish(tester, harness);
  });
}
