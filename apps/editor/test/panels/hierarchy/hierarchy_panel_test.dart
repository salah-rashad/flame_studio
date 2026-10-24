import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/app/app.dart';
import 'package:pyro/document/document.dart';
import 'package:pyro/panels/hierarchy/add_menu.dart';
import 'package:pyro/panels/hierarchy/hierarchy_model.dart';
import 'package:pyro/panels/panels.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro_runtime/pyro_runtime.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../../document/helpers/scenes.dart';
import '../../helpers/pump.dart';

/// root → a (→ a1 sprite, h hitbox), b, c: every built-in kind but the
/// circle, enough to drag around.
Scene sceneWithHitbox() => Scene(
  rootId: const NodeId('root'),
  nodes: {
    const NodeId('root'): RootNode(
      id: const NodeId('root'),
      childIds: const [NodeId('a'), NodeId('b'), NodeId('c')],
    ),
    const NodeId('a'): entity('a', children: ['a1', 'h']),
    const NodeId('a1'): sprite('a1'),
    const NodeId('h'): RectangleHitboxNode(
      id: const NodeId('h'),
      name: 'h',
      size: const Vec2(8, 8),
    ),
    const NodeId('b'): entity('b'),
    const NodeId('c'): entity('c'),
  },
);

void main() {
  late ProviderContainer container;
  late DocumentSession session;
  const level = 'level1';

  Future<void> pumpPanel(WidgetTester tester) async {
    final fs = MemoryFileSystem.test();
    fs.directory('/proj/assets/scenes').createSync(recursive: true);
    fs.directory('/recovery').createSync(recursive: true);
    fs
        .file('/proj/assets/scenes/level1.scene.json')
        .writeAsStringSync(SceneCodec.encode(sceneWithHitbox()));
    final services = SessionServices(
      files: SceneFiles(fileSystem: fs, offload: runInline),
      recovery: RecoveryStore(
        folder: '/recovery',
        fileSystem: fs,
        offload: runInline,
      ),
      projectRoot: '/proj',
      newId: counterIds(),
    );
    container = ProviderContainer();
    addTearDown(container.dispose);
    session = await DocumentSession.open(
      '/proj/assets/scenes/level1.scene.json',
      services: services,
    );
    container.read(sessionRegistryProvider.notifier).register(level, session);
    container
        .read(openScenesProvider.notifier)
        .open(
          const OpenScene(
            sceneId: level,
            path: '/proj/assets/scenes/level1.scene.json',
            displayName: 'level1',
          ),
        );
    await pumpPyro(
      tester,
      SizedBox(height: 400, child: HierarchyPanel(newId: counterIds('new'))),
      scope: (child) =>
          UncontrolledProviderScope(container: container, child: child),
    );
  }

  /// A widget test over the panel that closes its session inside the body,
  /// so no recovery timer's FakeTimer outlives the pending-timer check.
  void panelTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      await pumpPanel(tester);
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        // The rows' double-tap trackers still count down.
        await tester.pump(const Duration(milliseconds: 500));
        await session.discardAndClose();
      }
    });
  }

  SceneDocument current() => container.read(documentProvider(level)).document;

  List<String> childrenOf(String id) => [
    for (final child in current().node(NodeId(id))!.childIds) child.value,
  ];

  Finder row(String name) => find.widgetWithText(PrTreeRow<NodeId>, name).first;

  /// The row's top edge, a few pixels in: the "above" zone.
  Offset above(WidgetTester tester, String name) =>
      tester.getTopLeft(row(name)) + const Offset(60, 2);

  group('the tree', () {
    panelTest('shows the Nodes in childIds order with their names', (
      tester,
    ) async {
      final rows = tester
          .widgetList<PrTreeRow<NodeId>>(find.byType(PrTreeRow<NodeId>))
          .map((row) => (row.depth, row.name));
      expect(rows, [
        (0, 'level1'),
        (1, 'a'),
        (2, 'a1'),
        (2, 'h'),
        (1, 'b'),
        (1, 'c'),
      ]);
    });

    panelTest('selecting a row selects its Node', (tester) async {
      await tester.tap(row('b'));
      await tester.pump();
      expect(container.read(selectionProvider(level)), const NodeId('b'));
      expect(tester.widget<PrTreeRow<NodeId>>(row('b')).selected, isTrue);
    });
  });

  group('selection from elsewhere', () {
    panelTest(
      'a Node picked in the viewport is revealed in a collapsed branch',
      (tester) async {
        container
            .read(collapsedNodesProvider(level).notifier)
            .setCollapsed(const NodeId('a'), collapsed: true);
        await tester.pump();
        expect(find.widgetWithText(PrTreeRow<NodeId>, 'h'), findsNothing);

        container
            .read(selectionProvider(level).notifier)
            .select(const NodeId('h'));
        await tester.pump();
        await tester.pump();
        expect(row('h'), findsOneWidget);
        expect(tester.widget<PrTreeRow<NodeId>>(row('h')).selected, isTrue);
      },
    );
  });

  group('drag reparenting', () {
    panelTest('dropping a Node on another reparents it, as one undo step', (
      tester,
    ) async {
      await mouseDragTo(tester, row('b'), tester.getCenter(row('a')));
      expect(childrenOf('root'), ['a', 'c']);
      expect(childrenOf('a'), ['a1', 'h', 'b']);

      container.read(documentProvider(level).notifier).undo();
      expect(childrenOf('root'), ['a', 'b', 'c']);
      expect(childrenOf('a'), ['a1', 'h']);
    });

    panelTest('dropping above a sibling reorders within the parent', (
      tester,
    ) async {
      await mouseDragTo(tester, row('c'), above(tester, 'a'));
      expect(childrenOf('root'), ['c', 'a', 'b']);
    });

    panelTest('dropping a Node later among its siblings counts without it', (
      tester,
    ) async {
      await mouseDragTo(
        tester,
        row('a'),
        tester.getBottomLeft(row('b')) + const Offset(60, -2),
      );
      expect(childrenOf('root'), ['b', 'a', 'c']);
    });

    panelTest('a hitbox onto the root is refused with its reason', (
      tester,
    ) async {
      await mouseDragTo(tester, row('h'), tester.getCenter(row('level1')));
      expect(childrenOf('a'), ['a1', 'h']);
      expect(childrenOf('root'), ['a', 'b', 'c']);
      expect(find.text(hitboxUnderRootReason), findsOneWidget);
    });

    panelTest('a Node into its own subtree is refused, tree unchanged', (
      tester,
    ) async {
      await mouseDragTo(tester, row('a'), tester.getCenter(row('a1')));
      expect(childrenOf('root'), ['a', 'b', 'c']);
      expect(childrenOf('a'), ['a1', 'h']);
      expect(find.text("A Node can't be moved inside itself."), findsOneWidget);
    });

    panelTest('the root has no drag handle and takes no sibling drop', (
      tester,
    ) async {
      expect(tester.widget<PrTreeRow<NodeId>>(row('level1')).dragData, isNull);
      await mouseDragTo(tester, row('b'), above(tester, 'level1'));
      expect(childrenOf('root'), ['a', 'b', 'c']);
    });
  });

  group('the Add menu', () {
    Future<void> openAddMenu(WidgetTester tester) async {
      await tester.tap(find.byIcon(PrIcons.plus));
      await tester.pumpAndSettle();
    }

    panelTest('under the root offers an entity and disables the hitboxes', (
      tester,
    ) async {
      await openAddMenu(tester);
      expect(find.text('Entity'), findsOneWidget);

      // A disabled entry does nothing.
      await tester.tap(find.text('Rectangle hitbox'));
      await tester.pumpAndSettle();
      expect(childrenOf('root'), ['a', 'b', 'c']);

      await tester.tap(find.text('Entity'));
      await tester.pumpAndSettle();
      expect(childrenOf('root'), ['a', 'b', 'c', 'new1']);
      final added = current().node(const NodeId('new1'))!;
      expect(added, isA<EntityNode>());
      expect((added as EntityNode).name, 'Entity');
      expect(container.read(selectionProvider(level)), const NodeId('new1'));
    });

    panelTest('under an entity adds a hitbox, selected and in the tree', (
      tester,
    ) async {
      await tester.tap(row('b'));
      await tester.pump();
      await openAddMenu(tester);
      await tester.tap(find.text('Rectangle hitbox'));
      await tester.pumpAndSettle();
      expect(childrenOf('b'), ['new1']);
      expect(current().node(const NodeId('new1')), isA<RectangleHitboxNode>());
      expect(row('Rectangle hitbox'), findsOneWidget);
    });

    test('offers hitboxes only where the parenting table does', () {
      final catalog = builtInCatalog();
      final underRoot = addMenuEntries(
        catalog,
        const AddParent.root(),
        onAdd: (_) {},
      ).cast<PrMenuItem<void>>();
      expect({
        for (final item in underRoot) item.label: item.enabled,
      }, containsPair('Entity', true));
      expect({
        for (final item in underRoot) item.label: item.enabled,
      }, containsPair('Rectangle hitbox', false));
      expect(
        addRefusals(catalog, const AddParent.root()),
        contains(hitboxUnderRootReason),
      );
      final underEntity = addMenuEntries(
        catalog,
        const AddParent.type(TypeId('entity')),
        onAdd: (_) {},
      ).cast<PrMenuItem<void>>();
      expect(underEntity.every((item) => item.enabled), isTrue);
    });
  });

  group('rename and delete', () {
    panelTest('F2 renames in place; only the name changes', (tester) async {
      await tester.tap(row('b'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pump();
      await tester.enterText(find.byType(EditableText), 'Boss');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      final renamed = current().node(const NodeId('b'))! as EntityNode;
      expect(renamed.name, 'Boss');
      expect(row('Boss'), findsOneWidget);
      expect(childrenOf('root'), ['a', 'b', 'c']);
    });

    panelTest('delete takes the subtree; one undo brings it back', (
      tester,
    ) async {
      await tester.tap(row('a'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(current().contains(const NodeId('a1')), isFalse);
      expect(childrenOf('root'), ['b', 'c']);
      expect(container.read(selectionProvider(level)), const NodeId('root'));

      container.read(documentProvider(level).notifier).undo();
      await tester.pump();
      expect(childrenOf('root'), ['a', 'b', 'c']);
      expect(childrenOf('a'), ['a1', 'h']);
    });

    panelTest('holding Delete or F2 acts once, not on every key repeat', (
      tester,
    ) async {
      await tester.tap(row('a1'));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(current().contains(const NodeId('a1')), isFalse);
      // The selection is now `a`; the repeat must not delete it too.
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.delete);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(current().contains(const NodeId('a')), isTrue);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.delete);

      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.f2);
      await tester.pump();
      expect(find.byType(EditableText), findsNothing);
    });

    panelTest('the root is not deletable', (tester) async {
      await tester.tap(row('level1'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(childrenOf('root'), ['a', 'b', 'c']);
    });
  });
}

/// The built-in-only catalog, as a project with no Manifest has.
TypeCatalog builtInCatalog() {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  return c.read(typeCatalogProvider);
}
