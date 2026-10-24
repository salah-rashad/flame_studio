import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_runtime/pyro_runtime.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../inspector/harness.dart';
import 'behavior_helpers.dart';

void main() {
  List<BehaviorAttachment> behaviorsOfBox(InspectorHarness harness) =>
      (harness.node('box') as EntityNode).behaviors;

  testWidgets('Add Behavior offers the Behaviors the entity satisfies, '
      'grouped by category, and adds one at its code defaults (FR-035)', (
    tester,
  ) async {
    final harness = await openInspector(
      tester,
      types: [
        heroType(),
        spinType(),
        behaviorType('Aim', parentType: 'Enemy', category: 'Combat'),
        behaviorType('Blink'),
      ],
    );
    harness.select('box');
    await tester.pump();
    expect(find.text('No Behaviors yet.'), findsOneWidget);

    await tester.tap(find.byIcon(PrIcons.plus));
    await tester.pumpAndSettle();
    // Grouped, and without the one that needs an Enemy.
    expect(find.text('Motion'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
    expect(find.text('Spin'), findsOneWidget);
    expect(find.text('Blink'), findsOneWidget);
    expect(find.text('Aim'), findsNothing);
    expect(find.text('Combat'), findsNothing);

    await tester.tap(find.text('Spin'));
    await tester.pumpAndSettle();
    final added = behaviorsOfBox(harness);
    expect(added.map((b) => b.type.value), ['Spin']);
    expect(added.single.fields.isEmpty, isTrue);
    final turns = tester.widget<PrNumberProperty>(numberRow('turnsPerSecond'));
    expect(turns.value, 0.25);
    expect(turns.source, PrValueSource.codeDefault);

    // Editing marks an Override, as for any field.
    turns.onCommit(1.5);
    await tester.pump();
    expect(behaviorsOfBox(harness).single.fields['turnsPerSecond'], 1.5);
    expect(
      tester.widget<PrNumberProperty>(numberRow('turnsPerSecond')).source,
      PrValueSource.overridden,
    );
    await finish(tester, harness);
  });

  testWidgets('Remove Behavior drops the Behavior and its Overrides in one '
      'undoable transaction (FR-036)', (tester) async {
    final harness = await openInspector(
      tester,
      scene: sceneWithBehaviors([
        BehaviorAttachment(
          type: const TypeId('Spin'),
          fields: Overrides({'turnsPerSecond': 2}),
        ),
      ]),
      types: [heroType(), spinType()],
    );
    harness.select('box');
    await tester.pump();
    expect(numberRow('turnsPerSecond'), findsOneWidget);

    await tester.tap(find.byIcon(PrIcons.more));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove Behavior'));
    await tester.pumpAndSettle();
    expect(behaviorsOfBox(harness), isEmpty);
    expect(numberRow('turnsPerSecond'), findsNothing);

    harness.notifier.undo();
    await tester.pump();
    expect(behaviorsOfBox(harness).single.fields['turnsPerSecond'], 2);
    expect(numberRow('turnsPerSecond'), findsOneWidget);
    await finish(tester, harness);
  });

  testWidgets('a component that accepts no Behaviors disables Add with the '
      'reason (Q50)', (tester) async {
    final harness = await openInspector(
      tester,
      types: [heroType(), spinType()],
    );
    harness.select('hero');
    await tester.pump();
    final add = tester.widget<PrIconButton>(
      find.ancestor(
        of: find.byIcon(PrIcons.plus),
        matching: find.byType(PrIconButton),
      ),
    );
    expect(add.onPressed, isNull);
    expect(add.disabledReason, 'Hero does not accept Behaviors.');
    await finish(tester, harness);
  });

  testWidgets('a Behavior its entity no longer fits is marked incompatible '
      'with the reason, and keeps its values (FR-037)', (tester) async {
    final harness = await openInspector(
      tester,
      scene: sceneWithBehaviors([
        BehaviorAttachment(
          type: const TypeId('Aim'),
          fields: Overrides({'range': 4}),
        ),
      ]),
      types: [
        heroType(),
        enemyType(),
        behaviorType(
          'Aim',
          parentType: 'Enemy',
          fields: [field('range', FieldType.double, defaultValue: 1)],
        ),
      ],
    );
    harness.select('box');
    await tester.pump();
    expect(find.text('Incompatible'), findsOneWidget);
    expect(
      find.textContaining('Aim needs a Enemy, which Entity is not.'),
      findsOneWidget,
    );
    expect(tester.widget<PrNumberProperty>(numberRow('range')).value, 4);
    expect(behaviorsOfBox(harness).single.fields['range'], 4);
    await finish(tester, harness);
  });
}
