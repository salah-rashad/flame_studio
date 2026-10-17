import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';

import '../grid.dart';

class PanelPage extends StatelessWidget {
  const PanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GalleryPage(
      title: 'Panel',
      note:
          '28px header (surface-raised, title in heading, 16px icon, 20px '
          'actions, More overflow menu) · body surface-panel · focused: primary '
          'title + 2px accent-text top edge, rows use surface-selected · '
          'unfocused: secondary title, surface-selected-inactive.',
      children: [
        Wrap(
          spacing: FsSpacing.s6,
          runSpacing: FsSpacing.s4,
          children: [
            _Sample(
              label: 'Focused — accent top edge, ember selection',
              child: forced(
                const {WidgetState.focused},
                part: 'panel',
                _scenePanel(),
              ),
            ),
            _Sample(
              label: 'Unfocused — secondary title, grey selection',
              child: _scenePanel(),
            ),
            _Sample(
              label: 'Header actions: latched (lock), hover (more)',
              child: forced(
                const {WidgetState.hovered},
                part: 'overflow',
                FsPanel(
                  title: 'Inspector',
                  icon: FsIcons.sliders,
                  actions: [
                    FsIconButton(
                      icon: FsIcons.lock,
                      iconSize: FsSizes.iconSm,
                      size: FsIconButtonSize.small,
                      tooltip: 'Lock to selection',
                      selected: true,
                      onPressed: () {},
                    ),
                  ],
                  overflow: _overflow,
                  overflowTooltip: 'More',
                  body: const _InspectorBody(),
                ),
              ),
            ),
          ],
        ),
        const SectionLabel(
          'Live: click a panel (or a row) to focus it; Tab moves on; the '
          'zap toggle shows a header-progress stand-in',
        ),
        const _LivePanels(),
      ],
    );
  }
}

final _overflow = <FsMenuEntry<void>>[
  FsMenuItem(label: 'Collapse all', onSelected: () {}),
  FsMenuItem(label: 'Expand all', onSelected: () {}),
  const FsMenuSeparator(),
  FsMenuItem(label: 'Close panel', onSelected: () {}),
];

List<Widget> _sceneActions() => [
  FsIconButton(
    icon: FsIcons.plus,
    iconSize: FsSizes.iconSm,
    size: FsIconButtonSize.small,
    tooltip: 'Add',
    onPressed: () {},
  ),
  FsIconButton(
    icon: FsIcons.filter,
    iconSize: FsSizes.iconSm,
    size: FsIconButtonSize.small,
    tooltip: 'Filter',
    onPressed: () {},
  ),
];

Widget _scenePanel() => FsPanel(
  title: 'Scene',
  icon: FsIcons.listTree,
  actions: _sceneActions(),
  overflow: _overflow,
  overflowTooltip: 'More',
  body: const _SceneRows(),
);

class _SceneRows extends StatelessWidget {
  const _SceneRows();

  @override
  Widget build(BuildContext context) {
    final actions = [
      FsTreeRowAction(icon: FsIcons.eye, tooltip: 'Hide', onPressed: () {}),
      FsTreeRowAction(icon: FsIcons.lock, tooltip: 'Lock', onPressed: () {}),
    ];
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 2),
      children: [
        FsTreeRow<String>(
          depth: 0,
          name: 'level_1',
          icon: FsIcons.globe,
          hasChildren: true,
          expanded: true,
          actions: actions,
        ),
        FsTreeRow<String>(
          depth: 1,
          name: 'Camera',
          icon: FsIcons.video,
          actions: actions,
        ),
        FsTreeRow<String>(
          depth: 1,
          name: 'Player',
          icon: FsIcons.user,
          hasChildren: true,
          expanded: true,
          selected: true,
          tone: FsTreeRowTone.prefab,
          badges: const [FsBadge(kind: FsBadgeKind.prefab, label: 'Prefab')],
          actions: actions,
        ),
        FsTreeRow<String>(
          depth: 2,
          name: 'Sprite',
          icon: FsIcons.image,
          actions: actions,
        ),
        FsTreeRow<String>(
          depth: 1,
          name: 'Enemies',
          icon: FsIcons.layers,
          hasChildren: true,
          actions: actions,
        ),
      ],
    );
  }
}

class _InspectorBody extends StatefulWidget {
  const _InspectorBody();

  @override
  State<_InspectorBody> createState() => _InspectorBodyState();
}

class _InspectorBodyState extends State<_InspectorBody> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(FsSpacing.s2),
          child: FsSearchField(
            query: _query,
            onChanged: (q) => setState(() => _query = q),
            placeholder: 'Filter properties',
          ),
        ),
        Container(
          height: FsSizes.control,
          padding: const EdgeInsets.symmetric(horizontal: FsSpacing.s2),
          alignment: AlignmentDirectional.centerStart,
          color: c.surfaceRaised,
          child: Text(
            'PositionComponent',
            style: FsText.section.copyWith(color: c.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _Sample extends StatelessWidget {
  const _Sample({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 280,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        _Frame(width: 280, height: 176, child: child),
      ],
    ),
  );
}

/// The `ds-box` around a panel: a 1px border-subtle edge, clipped.
class _Frame extends StatelessWidget {
  const _Frame({
    required this.width,
    required this.height,
    required this.child,
  });

  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    foregroundDecoration: BoxDecoration(
      border: Border.all(color: FsColors.of(context).borderSubtle),
      borderRadius: FsRadii.sm,
    ),
    child: ClipRRect(borderRadius: FsRadii.sm, child: child),
  );
}

class _LivePanels extends StatefulWidget {
  const _LivePanels();

  @override
  State<_LivePanels> createState() => _LivePanelsState();
}

class _LivePanelsState extends State<_LivePanels> {
  String? _selected = 'Player';
  bool _locked = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    return Container(
      color: c.bgApp,
      padding: const EdgeInsets.all(1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 280,
            height: 220,
            child: FsPanel(
              title: 'Scene',
              icon: FsIcons.listTree,
              actions: _sceneActions(),
              overflow: _overflow,
              overflowTooltip: 'More',
              body: Builder(
                builder: (context) => ListView(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  children: [
                    for (final (depth, name, icon) in const [
                      (0, 'level_1', FsIcons.globe),
                      (1, 'Camera', FsIcons.video),
                      (1, 'Player', FsIcons.user),
                      (2, 'Sprite', FsIcons.image),
                      (1, 'Enemies', FsIcons.layers),
                    ])
                      FsTreeRow<String>(
                        depth: depth,
                        name: name,
                        icon: icon,
                        selected: name == _selected,
                        onTap: () => setState(() => _selected = name),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 1),
          SizedBox(
            width: 280,
            height: 220,
            child: FsPanel(
              title: 'Inspector',
              icon: FsIcons.sliders,
              actions: [
                FsToggleButton(
                  icon: FsIcons.lock,
                  iconSize: FsSizes.iconSm,
                  size: FsIconButtonSize.small,
                  tooltip: 'Lock to selection',
                  value: _locked,
                  onChanged: (v) => setState(() => _locked = v),
                ),
                FsToggleButton(
                  icon: FsIcons.zap,
                  iconSize: FsSizes.iconSm,
                  size: FsIconButtonSize.small,
                  tooltip: 'Busy (header progress)',
                  value: _busy,
                  onChanged: (v) => setState(() => _busy = v),
                ),
              ],
              overflow: _overflow,
              overflowTooltip: 'More',
              // Stand-in until FsProgressBar exists (Phase F).
              headerProgress: _busy
                  ? Container(height: 2, color: c.accentText)
                  : null,
              body: const _InspectorBody(),
            ),
          ),
        ],
      ),
    );
  }
}
