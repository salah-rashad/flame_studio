import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pyro/app/app.dart';
import 'package:pyro/document/document.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro_runtime/pyro_runtime.dart';
import 'package:pyro_ui/pyro_ui.dart';

import 'add_menu.dart';
import 'hierarchy_model.dart';
import 'node_edits.dart';

/// The Hierarchy panel (spec 006, work item 3): the active Scene's Node
/// tree on `PrTreeRow`s, with Add, rename, delete and drag reparenting
/// (FR-024–FR-028). Every change is one named transaction on the Scene's
/// document; the selection is the one the viewport and the inspector share.
class HierarchyPanel extends ConsumerWidget {
  /// Creates the panel. [newId] makes the IDs of added Nodes; tests pass a
  /// counter.
  const HierarchyPanel({super.key, this.newId = uuidNodeIds});

  /// Makes the ID of an added Node.
  final NodeIdSource newId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenes = ref.watch(openScenesProvider);
    final active = scenes.active;
    final scene = scenes.scenes.where((s) => s.sceneId == active).firstOrNull;
    if (scene == null) {
      return PrPanel(
        title: 'Hierarchy',
        icon: PrIcons.layers,
        body: Center(
          child: Text(
            'Open a Scene to see its Nodes.',
            style: PrText.small.copyWith(
              color: PrColors.of(context).textSecondary,
            ),
          ),
        ),
      );
    }
    return PrPanel(
      title: 'Hierarchy',
      icon: PrIcons.layers,
      actions: [_AddButton(sceneId: scene.sceneId, newId: newId)],
      body: _SceneTree(
        key: ValueKey(scene.sceneId),
        sceneId: scene.sceneId,
        rootName: scene.displayName,
        newId: newId,
      ),
    );
  }
}

/// What the panel does to one Scene: the one place the Add button, the
/// context menu, the keyboard and the rows reach the document and the
/// selection through.
class _Actions {
  _Actions(this.ref, this.sceneId, this.newId);

  final WidgetRef ref;
  final String sceneId;
  final NodeIdSource newId;

  DocumentNotifier get _document =>
      ref.read(documentProvider(sceneId).notifier);
  SceneDocument get doc => ref.read(documentProvider(sceneId)).document;
  TypeCatalog get catalog => ref.read(typeCatalogProvider);
  NodeId? get selected => ref.read(selectionProvider(sceneId));

  void select(NodeId? id) =>
      ref.read(selectionProvider(sceneId).notifier).select(id);

  void setCollapsed(NodeId id, {required bool collapsed}) => ref
      .read(collapsedNodesProvider(sceneId).notifier)
      .setCollapsed(id, collapsed: collapsed);

  bool isCollapsed(NodeId id) =>
      ref.read(collapsedNodesProvider(sceneId)).contains(id);

  /// Adds a Node of [typeId] under [parentId], shows it and selects it.
  void addChild(TypeId typeId, NodeId parentId) {
    final type = catalog[typeId];
    if (type == null) return;
    final id = addNodeOf(_document, type, parentId, newId: newId);
    setCollapsed(parentId, collapsed: false);
    select(id);
  }

  void rename(NodeId id, String name) => renameNode(_document, doc, id, name);

  /// Deletes [id] with its subtree; a selection inside it moves to the
  /// parent.
  void delete(NodeId id) {
    final before = doc;
    if (before.node(id) == null || id == before.rootId) return;
    final current = selected;
    final parent = before.parentOf(id);
    deleteNode(_document, before, id);
    if (current != null && (current == id || before.isAncestor(id, current))) {
      select(parent);
    }
  }

  /// Whether the drop is allowed. A refusal with a reason lands in
  /// [reason].
  bool canDrop(
    NodeId dragged,
    NodeId target,
    PrDropZone zone,
    ValueNotifier<String?> reason,
  ) {
    final check = checkDrop(doc, catalog, dragged, target, zone);
    reason.value = switch (check) {
      ReparentRefused(:final reason) when reason.isNotEmpty => reason,
      _ => null,
    };
    return check.allowed;
  }

  void drop(NodeId dragged, NodeId target, PrDropZone zone) {
    final placement = placementOf(doc, dragged, target, zone);
    if (placement == null) return;
    moveNodeTo(_document, doc, dragged, placement);
    setCollapsed(placement.parentId, collapsed: false);
    select(dragged);
  }
}

/// The header's Add button: the Add menu under the selected Node, or under
/// the root when nothing is selected (FR-025).
class _AddButton extends ConsumerWidget {
  const _AddButton({required this.sceneId, required this.newId});

  final String sceneId;
  final NodeIdSource newId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(typeCatalogProvider);
    final selection = ref.watch(selectionProvider(sceneId));
    final document = ref.watch(
      documentProvider(sceneId).select((view) => view.document),
    );
    final parent =
        document.node(selection ?? document.rootId) ??
        document.node(document.rootId)!;
    final addParent = addParentOf(parent);
    final actions = _Actions(ref, sceneId, newId);
    return PrMenuButton<void>(
      entries: addMenuEntries(
        catalog,
        addParent,
        onAdd: (type) => actions.addChild(type, parent.id),
      ),
      builder: (context, controller) => Semantics(
        label: 'Add child',
        button: true,
        excludeSemantics: true,
        child: PrTooltip(
          message: 'Add child',
          details: addRefusals(catalog, addParent),
          child: PrIconButton(
            size: PrIconButtonSize.small,
            icon: PrIcons.plus,
            tooltip: '',
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
          ),
        ),
      ),
    );
  }
}

/// One Scene's tree: the rows, the keyboard and the drop-refusal reason.
class _SceneTree extends ConsumerStatefulWidget {
  const _SceneTree({
    super.key,
    required this.sceneId,
    required this.rootName,
    required this.newId,
  });

  final String sceneId;
  final String rootName;
  final NodeIdSource newId;

  @override
  ConsumerState<_SceneTree> createState() => _SceneTreeState();
}

class _SceneTreeState extends ConsumerState<_SceneTree> {
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode(debugLabel: 'Hierarchy tree');
  final ValueNotifier<String?> _dropReason = ValueNotifier(null);
  NodeId? _renaming;

  late final _Actions _actions = _Actions(ref, widget.sceneId, widget.newId);

  String get _sceneId => widget.sceneId;

  @override
  void initState() {
    super.initState();
    // After the first frame: revealing expands ancestors, which changes a
    // provider, and a build may not.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reveal(_actions.selected),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    _focus.dispose();
    _dropReason.dispose();
    super.dispose();
  }

  /// Makes [id] visible: expands its ancestors and scrolls to its row
  /// (FR-024), for a selection made in the viewport or by keyboard.
  void _reveal(NodeId? id) {
    if (!mounted || id == null) return;
    final doc = _actions.doc;
    if (!doc.contains(id)) return;
    final hiding = [
      for (var p = doc.parentOf(id); p != null; p = doc.parentOf(p))
        if (_actions.isCollapsed(p)) p,
    ];
    if (hiding.isNotEmpty) {
      ref.read(collapsedNodesProvider(_sceneId).notifier).expandAll(hiding);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(id));
  }

  void _scrollTo(NodeId id) {
    if (!mounted || !_scroll.hasClients) return;
    final index = ref.read(visibleRowsProvider(_sceneId)).indexOf(id);
    if (index < 0) return;
    final top = index * PrSizes.rowTree;
    final bottom = top + PrSizes.rowTree;
    final position = _scroll.position;
    if (top < position.pixels) {
      _scroll.jumpTo(top);
    } else if (bottom > position.pixels + position.viewportDimension) {
      _scroll.jumpTo(bottom - position.viewportDimension);
    }
  }

  void _startRename(NodeId id) {
    if (_actions.doc.node(id) is! NamedNode) return;
    setState(() => _renaming = id);
  }

  void _endRename() {
    setState(() => _renaming = null);
    _focus.requestFocus();
  }

  void _commitRename(NodeId id, String name) {
    _actions.rename(id, name);
    _endRename();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || _renaming != null) return KeyEventResult.ignored;
    final doc = _actions.doc;
    final selected = _actions.selected;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      final rows = ref.read(visibleRowsProvider(_sceneId));
      final at = selected == null ? -1 : rows.indexOf(selected);
      final next = at < 0
          ? 0
          : (at + (key == LogicalKeyboardKey.arrowDown ? 1 : -1)).clamp(
              0,
              rows.rows.length - 1,
            );
      _select(rows.rows[next].id);
      return KeyEventResult.handled;
    }
    if (selected == null) return KeyEventResult.ignored;
    final current = doc.node(selected);
    if (current == null) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowRight) {
      if (current.childIds.isEmpty) return KeyEventResult.handled;
      if (_actions.isCollapsed(selected)) {
        _actions.setCollapsed(selected, collapsed: false);
      } else {
        _select(current.childIds.first);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (current.childIds.isNotEmpty && !_actions.isCollapsed(selected)) {
        _actions.setCollapsed(selected, collapsed: true);
      } else if (doc.parentOf(selected) case final parent?) {
        _select(parent);
      }
      return KeyEventResult.handled;
    }
    // Holding one of these must not rename again or delete the next Node
    // the selection lands on: only the first press acts.
    final pressed = event is KeyDownEvent;
    if (key == LogicalKeyboardKey.f2) {
      if (pressed) _startRename(selected);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      if (pressed) _actions.delete(selected);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _select(NodeId id) {
    _actions.select(id);
    _scrollTo(id);
  }

  Future<void> _showMenu(BuildContext context, Node node, Offset at) async {
    _actions.select(node.id);
    await showFsContextMenu<void>(
      context,
      position: at,
      entries: [
        PrMenuItem<void>(
          label: 'Add child',
          icon: PrIcons.plus,
          submenu: addMenuEntries(
            _actions.catalog,
            addParentOf(node),
            onAdd: (type) => _actions.addChild(type, node.id),
          ),
        ),
        PrMenuItem<void>(
          label: 'Rename',
          shortcut: const SingleActivator(LogicalKeyboardKey.f2),
          enabled: node is NamedNode,
          onSelected: () => _startRename(node.id),
        ),
        const PrMenuSeparator<void>(),
        PrMenuItem<void>(
          label: 'Delete',
          icon: PrIcons.trash,
          destructive: true,
          enabled: node is! RootNode,
          onSelected: () => _actions.delete(node.id),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(selectionProvider(_sceneId), (_, id) => _reveal(id));
    final rows = ref.watch(visibleRowsProvider(_sceneId)).rows;
    return Column(
      children: [
        Expanded(
          child: Focus(
            focusNode: _focus,
            onKeyEvent: _onKey,
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _focus.requestFocus(),
              child: ListView.builder(
                controller: _scroll,
                itemExtent: PrSizes.rowTree,
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return _NodeRow(
                    key: ValueKey(row.id),
                    sceneId: _sceneId,
                    row: row,
                    rootName: widget.rootName,
                    renaming: _renaming == row.id,
                    actions: _actions,
                    dropReason: _dropReason,
                    onSelect: _select,
                    onRename: _startRename,
                    onRenameCommit: _commitRename,
                    onRenameCancel: _endRename,
                    onMenu: _showMenu,
                  );
                },
              ),
            ),
          ),
        ),
        ValueListenableBuilder<String?>(
          valueListenable: _dropReason,
          builder: (context, reason, _) => reason == null
              ? const SizedBox.shrink()
              : PrBanner(
                  kind: PrStatusKind.warning,
                  message: TextSpan(text: reason),
                  onDismiss: () => _dropReason.value = null,
                  dismissTooltip: 'Dismiss',
                ),
        ),
      ],
    );
  }
}

/// One Node's row. Watches its own Node, so an edit rebuilds only the rows
/// it touched (constitution III).
class _NodeRow extends ConsumerWidget {
  const _NodeRow({
    super.key,
    required this.sceneId,
    required this.row,
    required this.rootName,
    required this.renaming,
    required this.actions,
    required this.dropReason,
    required this.onSelect,
    required this.onRename,
    required this.onRenameCommit,
    required this.onRenameCancel,
    required this.onMenu,
  });

  final String sceneId;
  final VisibleRow row;
  final String rootName;
  final bool renaming;
  final _Actions actions;
  final ValueNotifier<String?> dropReason;
  final ValueChanged<NodeId> onSelect;
  final ValueChanged<NodeId> onRename;
  final void Function(NodeId id, String name) onRenameCommit;
  final VoidCallback onRenameCancel;
  final Future<void> Function(BuildContext, Node, Offset) onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = row.id;
    final node = ref.watch(nodeProvider((sceneId, id)));
    if (node == null) return const SizedBox.shrink();
    final catalog = ref.watch(typeCatalogProvider);
    final selected = ref.watch(
      selectionProvider(sceneId).select((selection) => selection == id),
    );
    final collapsed = ref.watch(
      collapsedNodesProvider(sceneId).select((set) => set.contains(id)),
    );
    final missing = isMissing(node, catalog);
    final isRoot = node is RootNode;
    return PrTreeRow<NodeId>(
      depth: row.depth,
      name: labelOf(node, catalog, rootName: rootName),
      icon: iconOf(node),
      hasChildren: node.childIds.isNotEmpty,
      expanded: !collapsed,
      onExpandedChanged: (expanded) =>
          actions.setCollapsed(id, collapsed: !expanded),
      selected: selected,
      keyboardCursor: selected,
      tone: missing ? PrTreeRowTone.error : PrTreeRowTone.normal,
      badges: [
        if (missing) const PrBadge(kind: PrBadgeKind.missing, label: 'Missing'),
      ],
      onTap: () => onSelect(id),
      onDoubleTap: isRoot ? null : () => onRename(id),
      onSecondaryTap: (at) => onMenu(context, node, at),
      renaming: renaming,
      onRenameCommit: (name) => onRenameCommit(id, name),
      onRenameCancel: onRenameCancel,
      dragData: isRoot ? null : id,
      canHaveChildren: acceptsChildren(node, catalog),
      canAccept: (dragged, zone) =>
          actions.canDrop(dragged, id, zone, dropReason),
      onAccept: (dragged, zone) => actions.drop(dragged, id, zone),
      onAutoExpand: () => actions.setCollapsed(id, collapsed: false),
      onDragStarted: () => dropReason.value = null,
    );
  }
}
