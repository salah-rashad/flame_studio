import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/app/app.dart';
import 'package:pyro/document/document.dart';
import 'package:pyro/panels/panels.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro/viewport/viewport.dart';
import 'package:pyro_runtime/pyro_runtime.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../../document/helpers/scenes.dart';
import '../../helpers/pump.dart';

const sceneId = 'level1';
const scenePath = '/proj/assets/scenes/level1.scene.json';

FieldDescriptor field(
  String name,
  FieldType type, {
  Object? defaultValue,
  String? defaultSource,
  double? min,
  double? max,
  List<String>? values,
  bool nullable = false,
}) => FieldDescriptor(
  name: name,
  type: type,
  nullable: nullable,
  defaultValue: defaultValue,
  defaultSource: defaultSource,
  min: min,
  max: max,
  enumValues: values == null ? null : IList(values),
  tooltip: '$name tooltip',
);

/// A Custom component with one field of every Field type.
TypeDescriptor heroType() => TypeDescriptor(
  id: const TypeId('Hero'),
  role: TypeRole.component,
  label: 'Hero',
  supertypes: const ISet.empty(),
  acceptsBehaviors: false,
  builtIn: false,
  fields: IList([
    field('lives', FieldType.int, defaultValue: 3, min: 1, max: 5),
    field('speed', FieldType.double, defaultValue: 2.5, min: 0, max: 10),
    field('flying', FieldType.bool, defaultValue: false),
    field('label', FieldType.string, defaultValue: 'hero'),
    field(
      'mood',
      FieldType.enumeration,
      defaultValue: 'calm',
      values: ['calm', 'angry'],
    ),
    field('spawn', FieldType.vector2, defaultValue: [0, 0]),
    field(
      'portrait',
      FieldType.imagePath,
      defaultValue: {'asset': 'assets/images/hero.png'},
    ),
    field('tint', FieldType.color, defaultSource: 'const Color(0xFFFFFFFF)'),
    field('buddy', FieldType.entityRef, nullable: true),
    field('mask', FieldType.sprite, nullable: true),
    field('walk', FieldType.spriteAnimation, nullable: true),
    field('start', FieldType.double, defaultSource: 'computeStart()'),
  ]),
);

/// A catalog that is exactly [types] plus the built-ins.
class FixedCatalog extends TypeCatalogNotifier {
  FixedCatalog(this.types);

  final List<TypeDescriptor> types;

  static TypeCatalog catalogOf(List<TypeDescriptor> types) => TypeCatalog(
    types: IMap({
      for (final type in [...builtInTypes, ...types]) type.id: type,
    }),
    problems: const IList.empty(),
    origin: const ManifestUpToDate(),
  );

  @override
  TypeCatalog build() => catalogOf(types);

  /// Swaps the project's types, as a rewritten Manifest does.
  void replace(List<TypeDescriptor> types) => state = catalogOf(types);
}

/// root → hero (Hero), gone (a type the catalog lacks), box (entity,
/// → sprite s, → rectangle hitbox h).
Scene inspectorScene({Overrides heroFields = const Overrides.empty()}) => Scene(
  rootId: const NodeId('root'),
  nodes: {
    const NodeId('root'): RootNode(
      id: const NodeId('root'),
      childIds: const [NodeId('hero'), NodeId('gone'), NodeId('box')],
    ),
    const NodeId('hero'): CustomNode(
      id: const NodeId('hero'),
      name: 'hero',
      type: const TypeId('Hero'),
      transform: NodeTransform(position: const Vec2(10, 20)),
      fields: heroFields,
    ),
    const NodeId('gone'): CustomNode(
      id: const NodeId('gone'),
      name: 'gone',
      type: const TypeId('Gone'),
      transform: NodeTransform(),
      fields: Overrides({'secret': 42}),
    ),
    const NodeId('box'): entity('box', children: ['s', 'h']),
    const NodeId('s'): sprite('s'),
    const NodeId('h'): RectangleHitboxNode(
      id: const NodeId('h'),
      name: 'h',
      size: const Vec2(8, 8),
    ),
  },
);

/// An inspector over an open scene, with the session to save and reload.
class InspectorHarness {
  InspectorHarness(this.fs, this.session, this.container, this.services);

  final MemoryFileSystem fs;
  final DocumentSession session;
  final ProviderContainer container;
  final SessionServices services;

  SceneDocument get document =>
      container.read(documentProvider(sceneId)).document;

  DocumentNotifier get notifier =>
      container.read(documentProvider(sceneId).notifier);

  void select(String id) =>
      container.read(selectionProvider(sceneId).notifier).select(NodeId(id));

  bool get canUndo => container.read(documentProvider(sceneId)).canUndo;

  Node node(String id) => document.node(NodeId(id))!;

  /// Saves, and opens the file again.
  Future<DocumentSession> saveAndReopen() async {
    await session.save(runtimeReadsUpTo: 1);
    return DocumentSession.open(scenePath, services: services);
  }

  String get savedText => fs.file(scenePath).readAsStringSync();
}

Future<InspectorHarness> openInspector(
  WidgetTester tester, {
  Scene? scene,
  List<TypeDescriptor>? types,
}) async {
  final fs = MemoryFileSystem.test();
  fs.directory('/proj/assets/scenes').createSync(recursive: true);
  fs.directory('/proj/assets/images').createSync(recursive: true);
  fs.directory('/recovery').createSync(recursive: true);
  fs.file('/proj/pubspec.yaml').writeAsStringSync('''
name: proj
flutter:
  assets:
    - assets/images/
    - assets/scenes/
''');
  for (final image in ['hero.png', 'villain.png']) {
    fs.file('/proj/assets/images/$image').writeAsStringSync('x');
  }
  fs
      .file(scenePath)
      .writeAsStringSync(SceneCodec.encode(scene ?? inspectorScene()));
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
  final session = await DocumentSession.open(scenePath, services: services);
  final container = ProviderContainer(
    overrides: [
      typeCatalogProvider.overrideWith(
        () => FixedCatalog(types ?? [heroType()]),
      ),
      assetFileSystemProvider.overrideWithValue(fs),
    ],
  );
  addTearDown(container.dispose);
  container
      .read(projectProvider.notifier)
      .open(
        const ProjectState(
          root: '/proj',
          sdk: SdkInfo.none,
          compatibility: RuntimeCompatibility(
            status: RuntimeCompatStatus.ok,
            foundVersion: '0.0.1',
            readsUpTo: 1,
          ),
        ),
      );
  container.read(sessionRegistryProvider.notifier).register(sceneId, session);
  container
      .read(openScenesProvider.notifier)
      .open(
        const OpenScene(
          sceneId: sceneId,
          path: scenePath,
          displayName: 'level1',
        ),
      );
  await pumpPyro(
    tester,
    const SizedBox(height: 700, child: InspectorPanel()),
    width: 320,
    scope: (child) =>
        UncontrolledProviderScope(container: container, child: child),
  );
  return InspectorHarness(fs, session, container, services);
}

/// Closes the session inside the test body, so no recovery timer outlives
/// the pending-timer check.
Future<void> finish(WidgetTester tester, InspectorHarness harness) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await harness.session.discardAndClose();
  await tester.pump(const Duration(seconds: 1));
}

/// The number row labelled [label].
Finder numberRow(String label) => find.byWidgetPredicate(
  (widget) => widget is PrNumberProperty && widget.label == label,
);

Finder vectorRow(String label) => find.byWidgetPredicate(
  (widget) => widget is PrVector2Property && widget.label == label,
);

Finder boolRow(String label) => find.byWidgetPredicate(
  (widget) => widget is PrBoolProperty && widget.label == label,
);

Finder propertyRow(String label) => find.byWidgetPredicate(
  (widget) => widget is PrPropertyRow && widget.label == label,
);
