import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pyro/app/app.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro_runtime/pyro_runtime.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../hierarchy/node_edits.dart';
import 'field_editors.dart';
import 'inspector_edits.dart';
import 'transform_section.dart';

/// The Inspector panel (spec 006, work item 5): the selected Node's name,
/// transform and Editable fields (FR-029–FR-034). Every edit is a named
/// transaction on the Scene's document; undo works across the panels.
class InspectorPanel extends ConsumerStatefulWidget {
  /// Creates the panel.
  const InspectorPanel({super.key});

  @override
  ConsumerState<InspectorPanel> createState() => _InspectorPanelState();
}

class _InspectorPanelState extends ConsumerState<InspectorPanel> {
  final GestureKeys _gestures = GestureKeys();

  @override
  Widget build(BuildContext context) {
    final sceneId = ref.watch(
      openScenesProvider.select((scenes) => scenes.active),
    );
    return PrPanel(
      title: 'Inspector',
      icon: PrIcons.sliders,
      body: sceneId == null
          ? const _Notice('Open a Scene to inspect its Nodes.')
          : _SceneInspector(
              key: ValueKey(sceneId),
              sceneId: sceneId,
              gestures: _gestures,
            ),
    );
  }
}

/// The kind of Node selected, which is what the panel's layout depends on:
/// an edit to the Node's values rebuilds only the rows that show them.
typedef _Shape = ({Type kind, TypeId? type});

_Shape? _shapeOf(Node? node) => node == null
    ? null
    : (
        kind: node.runtimeType,
        type: switch (node) {
          EntityNode() => const TypeId('entity'),
          SpriteNode() => const TypeId('sprite'),
          RectangleHitboxNode() => const TypeId('rectangleHitbox'),
          CircleHitboxNode() => const TypeId('circleHitbox'),
          CustomNode(:final type) => type,
          RootNode() || UnknownNode() => null,
        },
      );

class _SceneInspector extends ConsumerWidget {
  const _SceneInspector({
    super.key,
    required this.sceneId,
    required this.gestures,
  });

  final String sceneId;
  final GestureKeys gestures;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodeId = ref.watch(selectionProvider(sceneId));
    final shape = nodeId == null
        ? null
        : ref.watch(nodeProvider((sceneId, nodeId)).select(_shapeOf));
    if (nodeId == null || shape == null) {
      return PrEmptyState(
        icon: PrIcons.sliders,
        title: 'Nothing selected',
        message: 'Select a Node in the Hierarchy or the viewport to edit it.',
        action: PrButton(
          label: 'Select the scene root',
          onPressed: () {
            final rootId = ref.read(documentProvider(sceneId)).document.rootId;
            ref.read(selectionProvider(sceneId).notifier).select(rootId);
          },
        ),
      );
    }
    if (shape.kind == RootNode) {
      return const _Notice('The scene root holds the Nodes; it has no fields.');
    }
    final catalog = ref.watch(typeCatalogProvider);
    final type = shape.type == null ? null : catalog[shape.type!];
    // A type the catalog doesn't know, or a kind this version doesn't:
    // nothing is invented, the values stay, and only what is safe is
    // editable (story 5, scenario 8).
    final missing = shape.kind == UnknownNode || type == null;
    return ListView(
      children: [
        if (missing)
          const PrBanner(
            kind: PrStatusKind.warning,
            message: TextSpan(
              text:
                  "This Node's type isn't in the project's types, so its "
                  'fields are kept as they are and not shown. Its name and '
                  'transform can still be edited.',
            ),
          ),
        PrPropertyList(
          children: [
            _NameRow(sceneId: sceneId, nodeId: nodeId, gestures: gestures),
          ],
        ),
        if (shape.kind != UnknownNode)
          _Section(
            title: 'Transform',
            icon: PrIcons.sliders,
            child: PrPropertyList(
              children: [
                TransformRows(
                  sceneId: sceneId,
                  nodeId: nodeId,
                  gestures: gestures,
                ),
              ],
            ),
          ),
        if (!missing && type.fields.isNotEmpty)
          _Section(
            title: type.label,
            icon: PrIcons.circleDot,
            child: PrPropertyList(
              children: [
                for (final field in type.fields)
                  FieldRow(
                    key: ValueKey('$nodeId/${field.name}'),
                    sceneId: sceneId,
                    nodeId: nodeId,
                    field: field,
                    gestures: gestures,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The Node's name (FR-027): the one field every non-root Node has.
class _NameRow extends ConsumerWidget {
  const _NameRow({
    required this.sceneId,
    required this.nodeId,
    required this.gestures,
  });

  final String sceneId;
  final NodeId nodeId;
  final GestureKeys gestures;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final node = ref.watch(nodeProvider((sceneId, nodeId)));
    if (node is! NamedNode) return const SizedBox.shrink();
    final edits = NodeEdits(ref, sceneId, nodeId, gestures);
    return PrPropertyRow(
      label: 'name',
      tooltip: 'The name game code looks the Node up by. Not unique.',
      editor: PrTextField(
        value: node.name ?? '',
        size: PrFieldSize.dense,
        onChanged: (text) => edits.edit('name', (n) => withName(n, text)),
        onSubmitted: (text) =>
            edits.edit('name', (n) => withName(n, text), end: true),
      ),
    );
  }
}

/// A titled, collapsible group of rows.
class _Section extends StatefulWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrSectionHeader(
          title: widget.title,
          icon: widget.icon,
          expanded: _expanded,
          onExpandedChanged: (expanded) => setState(() => _expanded = expanded),
        ),
        if (_expanded) widget.child,
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PrSpacing.s4),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: PrText.small.copyWith(
            color: PrColors.of(context).textSecondary,
          ),
        ),
      ),
    );
  }
}
