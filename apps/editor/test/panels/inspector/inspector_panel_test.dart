import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_runtime/pyro_runtime.dart';
import 'package:pyro_ui/pyro_ui.dart';

import 'harness.dart';

void main() {
  List<String> labels(WidgetTester tester) => [
    for (final row in tester.widgetList<PrPropertyRow>(
      find.byType(PrPropertyRow),
    ))
      row.label,
  ];

  testWidgets('with nothing selected it shows an empty state (FR-029)', (
    tester,
  ) async {
    final harness = await openInspector(tester);
    expect(find.text('Nothing selected'), findsOneWidget);
    expect(find.byType(PrPropertyRow), findsNothing);
    await finish(tester, harness);
  });

  testWidgets('a Custom component shows name, transform and its fields in '
      'Manifest order (FR-029)', (tester) async {
    final harness = await openInspector(tester);
    harness.select('hero');
    await tester.pump();
    expect(labels(tester), [
      'name',
      'position',
      'size',
      'scale',
      'angle',
      'anchor',
      'lives',
      'speed',
      'flying',
      'label',
      'mood',
      'spawn',
      'portrait',
      'tint',
      'buddy',
      'mask',
      'walk',
      'start',
    ]);
    await finish(tester, harness);
  });

  testWidgets('the transform rows never carry an Override marker or reset '
      '(Q89)', (tester) async {
    final harness = await openInspector(tester);
    harness.select('hero');
    await tester.pump();
    tester.widget<PrVector2Property>(vectorRow('position')).onCommit(30, 40);
    await tester.pump();
    final hero = harness.node('hero') as CustomNode;
    expect(hero.transform.position, const Vec2(30, 40));
    expect(hero.fields.isEmpty, isTrue);
    for (final label in ['position', 'size', 'scale']) {
      expect(
        tester.widget<PrVector2Property>(vectorRow(label)).source,
        PrValueSource.codeDefault,
      );
    }
    expect(
      tester.widget<PrNumberProperty>(numberRow('angle')).source,
      PrValueSource.codeDefault,
    );
    expect(find.byIcon(PrIcons.reset), findsNothing);
    await finish(tester, harness);
  });

  testWidgets('the angle is shown and typed in degrees, stored in radians', (
    tester,
  ) async {
    final harness = await openInspector(tester);
    harness.select('hero');
    await tester.pump();
    tester.widget<PrNumberProperty>(numberRow('angle')).onCommit(90);
    await tester.pump();
    expect(
      (harness.node('hero') as CustomNode).transform.angle,
      closeTo(1.5707963, 1e-6),
    );
    expect(
      tester.widget<PrNumberProperty>(numberRow('angle')).value,
      closeTo(90, 1e-9),
    );
    await finish(tester, harness);
  });

  testWidgets('a number past the Manifest range is clamped on commit '
      '(FR-031)', (tester) async {
    final harness = await openInspector(tester);
    harness.select('hero');
    await tester.pump();
    tester.widget<PrNumberProperty>(numberRow('lives')).onCommit(99);
    tester.widget<PrNumberProperty>(numberRow('speed')).onCommit(-3);
    await tester.pump();
    final fields = (harness.node('hero') as CustomNode).fields;
    expect(fields['lives'], 5);
    expect(fields['lives'], isA<int>());
    expect(fields['speed'], 0);
    await finish(tester, harness);
  });

  testWidgets('typed text outside the range is held invalid and writes '
      'nothing (FR-031)', (tester) async {
    final harness = await openInspector(tester);
    harness.select('hero');
    await tester.pump();
    final field = find.descendant(
      of: numberRow('lives'),
      matching: find.byType(EditableText),
    );
    await tester.tap(field);
    await tester.enterText(field, '99');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect((harness.node('hero') as CustomNode).fields.isEmpty, isTrue);
    await finish(tester, harness);
  });

  testWidgets('a scrub is one undo step (FR-034)', (tester) async {
    final harness = await openInspector(tester);
    harness.select('hero');
    await tester.pump();
    final speed = tester.widget<PrNumberProperty>(numberRow('speed'));
    speed.onChanged(3);
    speed.onChanged(4);
    speed.onChanged(5);
    speed.onCommit(5);
    await tester.pump();
    expect((harness.node('hero') as CustomNode).fields['speed'], 5);
    harness.notifier.undo();
    await tester.pump();
    expect((harness.node('hero') as CustomNode).fields.isEmpty, isTrue);
    expect(harness.canUndo, isFalse);
    await finish(tester, harness);
  });

  testWidgets('an enum offers the Manifest values, and a kept value still '
      'shows (FR-031)', (tester) async {
    final harness = await openInspector(
      tester,
      scene: inspectorScene(heroFields: Overrides({'mood': 'furious'})),
    );
    harness.select('hero');
    await tester.pump();
    final dropdown = tester.widget<PrDropdown<String>>(
      find.descendant(
        of: propertyRow('mood'),
        matching: find.byType(PrDropdown<String>),
      ),
    );
    expect(
      [for (final o in dropdown.options) o.value],
      ['calm', 'angry', 'furious'],
    );
    expect(dropdown.value, 'furious');
    await finish(tester, harness);
  });

  testWidgets('an image path lists the declared folders\' images, read from '
      'disk (Q31)', (tester) async {
    final harness = await openInspector(tester);
    harness.select('hero');
    await tester.pumpAndSettle();
    PrDropdown<String> portrait() => tester.widget<PrDropdown<String>>(
      find.descendant(
        of: propertyRow('portrait'),
        matching: find.byType(PrDropdown<String>),
      ),
    );
    expect(
      [for (final o in portrait().options) o.value],
      ['assets/images/hero.png', 'assets/images/villain.png'],
    );
    expect(portrait().value, 'assets/images/hero.png');

    portrait().onChanged!('assets/images/villain.png');
    await tester.pump();
    expect((harness.node('hero') as CustomNode).fields['portrait'], {
      'asset': 'assets/images/villain.png',
    });
    await finish(tester, harness);
  });

  testWidgets('Color, entity, Sprite and SpriteAnimation fields are '
      'read-only; a non-constant default shows its source (FR-033, §7.3)', (
    tester,
  ) async {
    final harness = await openInspector(
      tester,
      scene: inspectorScene(
        heroFields: Overrides({
          'tint': '#FF112233',
          'mask': {'asset': 'assets/images/hero.png'},
        }),
      ),
    );
    harness.select('hero');
    await tester.pump();
    for (final label in ['tint', 'buddy', 'mask', 'walk']) {
      expect(
        tester.widget<PrPropertyRow>(propertyRow(label)).readOnly,
        isTrue,
        reason: label,
      );
    }
    expect(find.text('#FF112233'), findsOneWidget);
    expect(find.text('assets/images/hero.png'), findsOneWidget);
    // A double whose default the generator could not evaluate.
    expect(find.text('computeStart()'), findsOneWidget);
    await finish(tester, harness);
  });

  testWidgets('a Missing type invents no field rows but keeps name and '
      'transform editable (story 5, scenario 8)', (tester) async {
    final harness = await openInspector(tester);
    harness.select('gone');
    await tester.pump();
    expect(
      find.textContaining('no longer exists in your code'),
      findsOneWidget,
    );
    // Its values show, read-only.
    expect(labels(tester), [
      'name',
      'position',
      'size',
      'scale',
      'angle',
      'anchor',
      'secret',
    ]);
    expect(
      tester.widget<PrPropertyRow>(propertyRow('secret')).readOnly,
      isTrue,
    );
    tester.widget<PrVector2Property>(vectorRow('position')).onCommit(5, 6);
    await tester.pump();
    final gone = harness.node('gone') as CustomNode;
    expect(gone.transform.position, const Vec2(5, 6));
    // The values it holds are kept.
    expect(gone.fields['secret'], 42);
    await finish(tester, harness);
  });

  testWidgets('built-in kinds show their own rows with no Override '
      'machinery', (tester) async {
    final harness = await openInspector(tester);
    harness.select('h');
    await tester.pump();
    expect(labels(tester), [
      'name',
      'position',
      'size',
      'angle',
      'anchor',
      'collisionType',
      'isSolid',
    ]);
    tester.widget<PrBoolProperty>(boolRow('isSolid')).onChanged!(true);
    await tester.pump();
    expect((harness.node('h') as RectangleHitboxNode).isSolid, isTrue);
    expect(find.byIcon(PrIcons.reset), findsNothing);

    harness.select('s');
    await tester.pumpAndSettle();
    expect(labels(tester), [
      'name',
      'position',
      'size',
      'scale',
      'angle',
      'anchor',
      'image',
      'region',
    ]);
    await finish(tester, harness);
  });

  testWidgets('renaming in the inspector changes only the name', (
    tester,
  ) async {
    final harness = await openInspector(tester);
    harness.select('box');
    await tester.pump();
    final name = tester.widget<PrTextField>(
      find.descendant(
        of: propertyRow('name'),
        matching: find.byType(PrTextField),
      ),
    );
    name.onSubmitted!('Crate');
    await tester.pump();
    final box = harness.node('box') as EntityNode;
    expect(box.name, 'Crate');
    expect(box.id, const NodeId('box'));
    expect(box.childIds, [const NodeId('s'), const NodeId('h')]);
    await finish(tester, harness);
  });
}
