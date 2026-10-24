import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro_runtime/pyro_runtime.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../inspector/harness.dart';
import 'behavior_helpers.dart';

void main() {
  testWidgets('a Behavior whose type left the catalog shows as Missing with '
      'its values, saves verbatim and returns editable (FR-037, FR-038, '
      'Q32)', (tester) async {
    final harness = await openInspector(
      tester,
      scene: sceneWithBehaviors([
        BehaviorAttachment(
          type: const TypeId('Spin'),
          fields: Overrides({'turnsPerSecond': 2}),
        ),
        BehaviorAttachment(
          type: const TypeId('Patrol'),
          fields: Overrides({
            'speed': 3,
            'route': ['a', 'b'],
          }),
          extra: const {'note': 'kept'},
        ),
      ]),
      types: [heroType(), spinType()],
    );
    final original = savedBehaviors(harness.savedText, 'box');
    harness.select('box');
    await tester.pump();

    // Marked Missing, values shown read-only.
    expect(
      find.textContaining('Patrol — Missing', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Missing'), findsWidgets);
    expect(
      find.textContaining(
        'Patrol no longer exists in your code. Its values '
        'are kept.',
      ),
      findsOneWidget,
    );
    expect(tester.widget<PrPropertyRow>(propertyRow('speed')).readOnly, isTrue);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('[a, b]'), findsOneWidget);
    expect(numberRow('speed'), findsNothing);

    // Editing its neighbour and saving leaves the Missing one verbatim.
    tester.widget<PrNumberProperty>(numberRow('turnsPerSecond')).onCommit(3);
    await tester.pump();
    await harness.session.save(runtimeReadsUpTo: 1);
    final saved = savedBehaviors(harness.savedText, 'box');
    expect(saved[1], original[1]);
    expect(saved[0], isNot(original[0]));
    final reopened = await harness.saveAndReopen();
    final behaviors =
        (reopened.state.state.node(const NodeId('box'))! as EntityNode)
            .behaviors;
    expect(behaviors[1].fields.values, {
      'speed': 3,
      'route': ['a', 'b'],
    });
    expect(behaviors[1].extra, {'note': 'kept'});
    await reopened.discardAndClose();

    // The type returns: it renders and edits normally, values intact.
    (harness.container.read(typeCatalogProvider.notifier) as FixedCatalog)
        .replace([heroType(), spinType(), patrolType()]);
    await tester.pump();
    expect(find.text('Missing'), findsNothing);
    final speed = tester.widget<PrNumberProperty>(numberRow('speed'));
    expect(speed.value, 3);
    expect(speed.source, PrValueSource.overridden);
    speed.onCommit(5);
    await tester.pump();
    expect((harness.node('box') as EntityNode).behaviors[1].fields['speed'], 5);
    await finish(tester, harness);
  });
}
