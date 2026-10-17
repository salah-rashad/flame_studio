import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../grid.dart';

class TreeRowPage extends StatelessWidget {
  const TreeRowPage({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      FsTreeRowAction(icon: FsIcons.eye, tooltip: 'Hide', onPressed: () {}),
      FsTreeRowAction(icon: FsIcons.unlock, tooltip: 'Lock', onPressed: () {}),
    ];
    FsTreeRow<String> player({bool selected = false, bool renaming = false}) =>
        FsTreeRow<String>(
          depth: 1,
          name: 'Player',
          icon: FsIcons.image,
          hasChildren: true,
          expanded: true,
          selected: selected,
          renaming: renaming,
          actions: actions,
          onTap: () {},
        );
    Widget single(Widget row) => Padding(
      padding: const EdgeInsets.symmetric(vertical: FsSpacing.s1),
      child: row,
    );
    Widget dropGroup(String part) => Padding(
      padding: const EdgeInsets.symmetric(vertical: FsSpacing.s1),
      child: Column(
        children: [
          const FsTreeRow<String>(
            depth: 1,
            name: 'Camera',
            icon: FsIcons.video,
          ),
          forced(
            part == 'reject'
                ? const {WidgetState.error}
                : const {WidgetState.hovered},
            part: part == 'reject' ? 'drop-inside' : part,
            player(),
          ),
          const FsTreeRow<String>(
            depth: 1,
            name: 'Enemies',
            icon: FsIcons.layers,
            hasChildren: true,
          ),
        ],
      ),
    );

    return GalleryPage(
      title: 'TreeRow',
      note:
          '22px row · 16px indent per level + 4 · 16px chevron box · 14px type '
          'icon · name · badges · row actions (hover only, or pinned when the '
          'state is not the default).',
      children: [
        StateGrid(
          columns: const ['Scene tree'],
          rows: [
            GridRow('Default', [single(player())]),
            GridRow('Hover — row actions appear', [
              single(forced(const {WidgetState.hovered}, player())),
            ]),
            GridRow('Pressed', [
              single(forced(const {WidgetState.pressed}, player())),
            ]),
            GridRow('Focused (keyboard cursor)', [
              single(forced(const {WidgetState.focused}, player())),
            ]),
            GridRow('Selected · panel focused', [
              single(player(selected: true)),
            ]),
            GridRow('Selected · panel unfocused', [
              single(FsPanelFocus(child: player(selected: true))),
            ]),
            GridRow('Focused + selected', [
              single(
                forced(const {WidgetState.focused}, player(selected: true)),
              ),
            ]),
            GridRow('Disabled (hidden node)', [
              single(
                FsTreeRow<String>(
                  depth: 1,
                  name: 'HUD',
                  icon: FsIcons.layers,
                  hasChildren: true,
                  tone: FsTreeRowTone.dimmed,
                  actions: [
                    FsTreeRowAction(
                      icon: FsIcons.eyeOff,
                      tooltip: 'Show',
                      onPressed: () {},
                      pinned: true,
                    ),
                  ],
                ),
              ),
            ]),
            GridRow('Error', [
              single(
                FsTreeRow<String>(
                  depth: 1,
                  name: 'Bat',
                  icon: FsIcons.image,
                  tone: FsTreeRowTone.error,
                  badges: [
                    const FsBadge(
                      kind: FsBadgeKind.missing,
                      label: 'Missing script',
                    ),
                  ],
                  actions: actions,
                ),
              ),
            ]),
            GridRow('Badges', [
              single(
                FsTreeRow<String>(
                  depth: 1,
                  name: 'Slime 2',
                  icon: FsIcons.box,
                  tone: FsTreeRowTone.prefab,
                  badges: [
                    const FsBadge(kind: FsBadgeKind.warning, count: 2),
                    const FsBadge(kind: FsBadgeKind.prefab, label: 'Prefab'),
                  ],
                  actions: actions,
                ),
              ),
            ]),
            GridRow('Inline rename', [
              single(player(selected: true, renaming: true)),
            ]),
            GridRow('Drag over — above', [dropGroup('drop-above')]),
            GridRow('Drag over — inside', [dropGroup('drop-inside')]),
            GridRow('Drag over — below', [dropGroup('drop-below')]),
            GridRow('Drop not allowed', [dropGroup('reject')]),
          ],
        ),
        const SectionLabel(
          'Live: click, ⇧/⌘ not handled here; drag rows to reparent; F2 renames',
        ),
        const SampleBox(width: 320, child: _LiveTree()),
      ],
    );
  }
}

class _Node {
  _Node(this.name, this.icon, [List<_Node>? children])
    : children = children ?? [];

  String name;
  final IconData icon;
  final List<_Node> children;
  bool expanded = true;
  _Node? parent;
}

class _LiveTree extends StatefulWidget {
  const _LiveTree();

  @override
  State<_LiveTree> createState() => _LiveTreeState();
}

class _LiveTreeState extends State<_LiveTree> {
  late final _Node _root = _link(
    _Node('World', FsIcons.globe, [
      _Node('Camera', FsIcons.video),
      _Node('Player', FsIcons.image, [
        _Node('Hitbox', FsIcons.hitbox),
        _Node('Label', FsIcons.type),
      ]),
      _Node('Enemies', FsIcons.layers, [_Node('Bat', FsIcons.film)]),
    ]),
  );
  _Node? _selected;
  _Node? _renaming;

  static _Node _link(_Node node) {
    for (final child in node.children) {
      child.parent = node;
      _link(child);
    }
    return node;
  }

  Iterable<(_Node, int)> _visible(_Node node, int depth) sync* {
    yield (node, depth);
    if (!node.expanded) return;
    for (final child in node.children) {
      yield* _visible(child, depth + 1);
    }
  }

  bool _isAncestor(_Node a, _Node b) {
    for (_Node? n = b; n != null; n = n.parent) {
      if (n == a) return true;
    }
    return false;
  }

  bool _canAccept(_Node dragged, _Node target, FsDropZone zone) {
    if (_isAncestor(dragged, target)) return false; // into itself or a child
    if (zone != FsDropZone.inside && target.parent == null) return false;
    return true;
  }

  void _move(_Node dragged, _Node target, FsDropZone zone) => setState(() {
    dragged.parent?.children.remove(dragged);
    if (zone == FsDropZone.inside) {
      target.children.add(dragged);
      dragged.parent = target;
    } else {
      final siblings = target.parent!.children;
      final i = siblings.indexOf(target);
      siblings.insert(zone == FsDropZone.above ? i : i + 1, dragged);
      dragged.parent = target.parent;
    }
  });

  @override
  Widget build(BuildContext context) {
    return FsPanelFocus(
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.f2 &&
              _selected != null) {
            setState(() => _renaming = _selected);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (context) => Column(
            children: [
              for (final (node, depth) in _visible(_root, 0))
                FsTreeRow<_Node>(
                  key: ObjectKey(node),
                  depth: depth,
                  name: node.name,
                  icon: node.icon,
                  hasChildren: node.children.isNotEmpty,
                  expanded: node.expanded,
                  onExpandedChanged: (v) => setState(() => node.expanded = v),
                  selected: node == _selected,
                  onTap: () {
                    Focus.of(context).requestFocus();
                    setState(() => _selected = node);
                  },
                  onDoubleTap: () => setState(() => _renaming = node),
                  renaming: node == _renaming,
                  onRenameCommit: (name) => setState(() {
                    if (name.trim().isNotEmpty) node.name = name.trim();
                    _renaming = null;
                  }),
                  onRenameCancel: () => setState(() => _renaming = null),
                  dragData: node.parent == null ? null : node,
                  canAccept: (dragged, zone) => _canAccept(dragged, node, zone),
                  onAccept: (dragged, zone) => _move(dragged, node, zone),
                  onAutoExpand: () => setState(() => node.expanded = true),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
