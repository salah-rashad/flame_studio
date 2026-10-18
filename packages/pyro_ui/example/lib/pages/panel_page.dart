import 'package:flutter/material.dart';
import 'package:pyro_ui/pyro_ui.dart';

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
          spacing: PrSpacing.s6,
          runSpacing: PrSpacing.s4,
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
                PrPanel(
                  title: 'Inspector',
                  icon: PrIcons.sliders,
                  actions: [
                    PrIconButton(
                      icon: PrIcons.lock,
                      iconSize: PrSizes.iconSm,
                      size: PrIconButtonSize.small,
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
          'Live',
          detail:
              'click a panel (or a row) to focus it; Tab moves on; the zap '
              'toggle shows a PrProgressBar as header progress',
        ),
        const _LivePanels(),
      ],
    );
  }
}

final _overflow = <PrMenuEntry<void>>[
  PrMenuItem(label: 'Collapse all', onSelected: () {}),
  PrMenuItem(label: 'Expand all', onSelected: () {}),
  const PrMenuSeparator(),
  PrMenuItem(label: 'Close panel', onSelected: () {}),
];

List<Widget> _sceneActions() => [
  PrIconButton(
    icon: PrIcons.plus,
    iconSize: PrSizes.iconSm,
    size: PrIconButtonSize.small,
    tooltip: 'Add',
    onPressed: () {},
  ),
  PrIconButton(
    icon: PrIcons.filter,
    iconSize: PrSizes.iconSm,
    size: PrIconButtonSize.small,
    tooltip: 'Filter',
    onPressed: () {},
  ),
];

Widget _scenePanel() => PrPanel(
  title: 'Scene',
  icon: PrIcons.listTree,
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
      PrTreeRowAction(icon: PrIcons.eye, tooltip: 'Hide', onPressed: () {}),
      PrTreeRowAction(icon: PrIcons.lock, tooltip: 'Lock', onPressed: () {}),
    ];
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 2),
      children: [
        PrTreeRow<String>(
          depth: 0,
          name: 'level_1',
          icon: PrIcons.globe,
          hasChildren: true,
          expanded: true,
          actions: actions,
        ),
        PrTreeRow<String>(
          depth: 1,
          name: 'Camera',
          icon: PrIcons.video,
          actions: actions,
        ),
        PrTreeRow<String>(
          depth: 1,
          name: 'Player',
          icon: PrIcons.user,
          hasChildren: true,
          expanded: true,
          selected: true,
          tone: PrTreeRowTone.prefab,
          badges: const [PrBadge(kind: PrBadgeKind.prefab, label: 'Prefab')],
          actions: actions,
        ),
        PrTreeRow<String>(
          depth: 2,
          name: 'Sprite',
          icon: PrIcons.image,
          actions: actions,
        ),
        PrTreeRow<String>(
          depth: 1,
          name: 'Enemies',
          icon: PrIcons.layers,
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
    final c = PrColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(PrSpacing.s2),
          child: PrSearchField(
            query: _query,
            onChanged: (q) => setState(() => _query = q),
            placeholder: 'Filter properties',
          ),
        ),
        Container(
          height: PrSizes.control,
          padding: const EdgeInsets.symmetric(horizontal: PrSpacing.s2),
          alignment: AlignmentDirectional.centerStart,
          color: c.surfaceRaised,
          child: Text(
            'PositionComponent',
            style: PrText.section.copyWith(color: c.textPrimary),
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
      border: Border.all(color: PrColors.of(context).borderSubtle),
      borderRadius: PrRadii.sm,
    ),
    child: ClipRRect(borderRadius: PrRadii.sm, child: child),
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
    final c = PrColors.of(context);
    return Container(
      color: c.bgApp,
      padding: const EdgeInsets.all(1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 280,
            height: 220,
            child: PrPanel(
              title: 'Scene',
              icon: PrIcons.listTree,
              actions: _sceneActions(),
              overflow: _overflow,
              overflowTooltip: 'More',
              body: Builder(
                builder: (context) => ListView(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  children: [
                    for (final (depth, name, icon) in const [
                      (0, 'level_1', PrIcons.globe),
                      (1, 'Camera', PrIcons.video),
                      (1, 'Player', PrIcons.user),
                      (2, 'Sprite', PrIcons.image),
                      (1, 'Enemies', PrIcons.layers),
                    ])
                      PrTreeRow<String>(
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
            child: PrPanel(
              title: 'Inspector',
              icon: PrIcons.sliders,
              actions: [
                PrToggleButton(
                  icon: PrIcons.lock,
                  iconSize: PrSizes.iconSm,
                  size: PrIconButtonSize.small,
                  tooltip: 'Lock to selection',
                  value: _locked,
                  onChanged: (v) => setState(() => _locked = v),
                ),
                PrToggleButton(
                  icon: PrIcons.zap,
                  iconSize: PrSizes.iconSm,
                  size: PrIconButtonSize.small,
                  tooltip: 'Busy (header progress)',
                  value: _busy,
                  onChanged: (v) => setState(() => _busy = v),
                ),
              ],
              overflow: _overflow,
              overflowTooltip: 'More',
              headerProgress: _busy ? const PrProgressBar() : null,
              body: const _InspectorBody(),
            ),
          ),
        ],
      ),
    );
  }
}
