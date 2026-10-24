import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_runtime/pyro_runtime.dart';
import 'package:pyro_ui/pyro_ui.dart';

import 'harness.dart';

void main() {
  testWidgets(
    'setting an Override marks the row, Reset to default clears it, undo '
    'brings the Override back in one step (FR-032, ADR 0003)',
    (tester) async {
      final harness = await openInspector(tester);
      harness.select('hero');
      await tester.pump();

      PrNumberProperty speed() =>
          tester.widget<PrNumberProperty>(numberRow('speed'));

      // Un-overridden: the code default, no marker, no reset button.
      expect(speed().value, 2.5);
      expect(speed().source, PrValueSource.codeDefault);
      expect(
        find.descendant(
          of: propertyRow('speed'),
          matching: find.byIcon(PrIcons.reset),
        ),
        findsNothing,
      );

      // Set: the Override is written and the row carries the marker.
      speed().onCommit(7);
      await tester.pump();
      expect((harness.node('hero') as CustomNode).fields['speed'], 7);
      expect(speed().value, 7);
      expect(speed().source, PrValueSource.overridden);
      final reset = find.descendant(
        of: propertyRow('speed'),
        matching: find.byIcon(PrIcons.reset),
      );
      expect(reset, findsOneWidget);

      // Reset: the Override is gone and the code default shows again.
      await tester.tap(reset);
      await tester.pump();
      expect(
        (harness.node('hero') as CustomNode).fields.contains('speed'),
        isFalse,
      );
      expect(speed().value, 2.5);
      expect(speed().source, PrValueSource.codeDefault);

      // One undo restores the Override.
      harness.notifier.undo();
      await tester.pump();
      expect((harness.node('hero') as CustomNode).fields['speed'], 7);
      expect(speed().source, PrValueSource.overridden);

      await finish(tester, harness);
    },
  );
}
