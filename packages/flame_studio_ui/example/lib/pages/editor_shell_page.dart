import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';

import '../grid.dart';

/// The window sizes the preview can be shown at; null fills the page.
const _windows = <String, Size?>{
  'Fill': null,
  '1440×900': Size(1440, 900),
  '1280×800': Size(1280, 800),
};

/// The EditorShell preview: the whole window assembled from the package's
/// widgets with placeholder content, the integration check that the pieces
/// fit (plan §6.1).
class EditorShellPage extends StatefulWidget {
  const EditorShellPage({super.key});

  @override
  State<EditorShellPage> createState() => _EditorShellPageState();
}

class _EditorShellPageState extends State<EditorShellPage> {
  String _window = '1440×900';
  FsShellSizes _sizes = FsShellSizes.standard;
  FsShellSizes? _saved;
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    final window = _windows[_window];
    final shell = FsEditorShell(
      titleBar: const _TitleBar(),
      toolbar: const _MainToolbar(),
      left: const _ScenePanel(),
      center: const _Center(),
      right: const _InspectorPanel(),
      bottom: _Dock(
        collapsed: _collapsed,
        onCollapsedChanged: (v) => setState(() => _collapsed = v),
      ),
      bottomCollapsed: _collapsed,
      onBottomCollapsedChanged: (v) => setState(() => _collapsed = v),
      statusBar: const _StatusBar(),
      sizes: _sizes,
      onSizesChanged: (v) => setState(() => _sizes = v),
      onSizesChangeEnd: (v) => setState(() => _saved = v),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(FsSpacing.s4),
          child: Row(
            spacing: FsSpacing.s4,
            children: [
              Text(
                'EditorShell',
                style: FsText.title.copyWith(color: c.textPrimary),
              ),
              FsSegmentedControl<String>(
                segments: [
                  for (final name in _windows.keys)
                    FsSegment(value: name, label: name),
                ],
                selected: _window,
                onChanged: (v) => setState(() => _window = v),
              ),
              FsButton(
                label: 'Reset sizes',
                variant: FsButtonVariant.ghost,
                onPressed: () => setState(() {
                  _sizes = FsShellSizes.standard;
                  _collapsed = false;
                }),
              ),
              Expanded(
                child: Text(
                  'Drag the seams; a window too small for the docks shrinks '
                  'them in layout only. Saved on drag end: '
                  '${_saved ?? 'nothing yet'}',
                  style: FsText.small.copyWith(color: c.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              FsSpacing.s4,
              0,
              FsSpacing.s4,
              FsSpacing.s4,
            ),
            child: window == null
                ? shell
                : FittedBox(
                    alignment: Alignment.topLeft,
                    child: SizedBox.fromSize(size: window, child: shell),
                  ),
          ),
        ),
      ],
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Platformer — level_1.scene', maxLines: 1));
}

class _MainToolbar extends StatelessWidget {
  const _MainToolbar();

  @override
  Widget build(BuildContext context) => const FsToolbar(
    leading: [
      FsToolbarGroup(
        children: [
          FsIconButton(icon: FsIcons.undo, tooltip: 'Undo', onPressed: noop),
          FsIconButton(
            icon: FsIcons.redo,
            tooltip: 'Redo',
            disabledReason: 'Nothing to redo',
            onPressed: null,
          ),
        ],
      ),
      FsToolbarGroup(
        children: [
          FsSegmentedControl<String>(
            segments: [
              FsSegment(
                value: 'select',
                icon: FsIcons.pointer,
                tooltip: 'Select',
              ),
              FsSegment(value: 'move', icon: FsIcons.move, tooltip: 'Move'),
              FsSegment(
                value: 'rotate',
                icon: FsIcons.rotate,
                tooltip: 'Rotate',
              ),
              FsSegment(value: 'scale', icon: FsIcons.scale, tooltip: 'Scale'),
            ],
            selected: 'move',
            onChanged: noop,
          ),
        ],
      ),
      FsToolbarGroup(
        children: [
          FsToggleButton(
            icon: FsIcons.magnet,
            label: '8 px',
            value: true,
            tooltip: 'Snap to grid',
            onChanged: noop,
          ),
        ],
      ),
    ],
    center: [
      FsToolbarGroup(
        children: [
          FsSplitButton<String>(
            label: 'Play',
            leading: FsPlayGlyph(size: 14),
            onPressed: noop,
            menuItems: [FsMenuItem(label: 'Play in window', value: 'window')],
            onSelected: noop,
            tooltip: 'Play',
            menuTooltip: 'Play options',
          ),
          FsIconButton(
            icon: FsIcons.stop,
            tooltip: 'Stop',
            disabledReason: 'The game is not running',
            onPressed: null,
          ),
        ],
      ),
    ],
    trailing: [
      FsToolbarGroup(
        spacing: FsSpacing.s2,
        children: [
          FsDeviceChip(
            icon: FsIcons.smartphone,
            label: 'iPhone 16 Simulator',
            selected: true,
            onPressed: noop,
          ),
          FsStatusDot(status: FsStatus.idle, label: 'Hot reload ready'),
        ],
      ),
    ],
  );
}

class _ScenePanel extends StatelessWidget {
  const _ScenePanel();

  @override
  Widget build(BuildContext context) => FsPanel(
    title: 'Scene',
    icon: FsIcons.listTree,
    actions: [
      const FsIconButton(
        icon: FsIcons.plus,
        iconSize: FsSizes.iconSm,
        size: FsIconButtonSize.small,
        tooltip: 'Add node',
        onPressed: noop,
      ),
    ],
    body: ListView(
      padding: const EdgeInsets.symmetric(vertical: FsSpacing.s1),
      children: [
        const FsTreeRow<String>(
          depth: 0,
          name: 'Level1',
          icon: FsIcons.layers,
          hasChildren: true,
          expanded: true,
          onTap: noop,
        ),
        const FsTreeRow<String>(
          depth: 1,
          name: 'Player',
          icon: FsIcons.image,
          selected: true,
          onTap: noop,
        ),
        const FsTreeRow<String>(
          depth: 1,
          name: 'Camera',
          icon: FsIcons.video,
          onTap: noop,
        ),
        const FsTreeRow<String>(
          depth: 1,
          name: 'Enemies',
          icon: FsIcons.layers,
          hasChildren: true,
          onTap: noop,
        ),
      ],
    ),
  );
}

class _Center extends StatelessWidget {
  const _Center();

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    return ColoredBox(
      color: c.surfacePanel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FsTabs<String>(
            tabs: [
              FsTab(value: 'level', label: 'level_1.scene', icon: FsIcons.file),
              FsTab(
                value: 'menu',
                label: 'main_menu.scene',
                icon: FsIcons.file,
                dirty: true,
              ),
            ],
            selected: 'level',
            onSelect: noop,
            onClose: noop,
            closeTooltip: 'Close',
          ),
          const FsToolbar(
            style: FsToolbarStyle.viewport,
            leading: [
              FsToolbarGroup(
                children: [
                  FsToggleButton(
                    icon: FsIcons.grid,
                    value: true,
                    tooltip: 'Show grid',
                    onChanged: noop,
                  ),
                  FsToggleButton(
                    icon: FsIcons.hitbox,
                    value: false,
                    tooltip: 'Show hitboxes',
                    onChanged: noop,
                  ),
                ],
              ),
            ],
          ),
          Expanded(child: ColoredBox(color: c.bgViewport)),
        ],
      ),
    );
  }
}

class _InspectorPanel extends StatelessWidget {
  const _InspectorPanel();

  @override
  Widget build(BuildContext context) => FsPanel(
    title: 'Inspector',
    icon: FsIcons.sliders,
    body: ListView(
      children: [
        const FsSectionHeader(
          title: 'PositionComponent',
          expanded: true,
          onExpandedChanged: noop,
        ),
        const FsPropertyList(
          children: [
            FsVector2Property(
              label: 'position',
              x: 412.5,
              y: 288,
              onChanged: noop,
              onCommit: noop,
            ),
            FsNumberProperty(
              label: 'angle',
              value: 0,
              onChanged: noop,
              onCommit: noop,
            ),
            FsBoolProperty(label: 'debugMode', value: false, onChanged: noop),
          ],
        ),
      ],
    ),
  );
}

class _Dock extends StatelessWidget {
  const _Dock({required this.collapsed, required this.onCollapsedChanged});

  final bool collapsed;
  final ValueChanged<bool> onCollapsedChanged;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    return FsPanelFocus(
      child: ColoredBox(
        color: c.surfacePanel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: FsTabs<String>(
                    style: FsTabsStyle.dock,
                    tabs: [
                      FsTab(
                        value: 'console',
                        label: 'Console',
                        icon: FsIcons.terminal,
                      ),
                      FsTab(
                        value: 'assets',
                        label: 'Assets',
                        icon: FsIcons.folder,
                      ),
                    ],
                    selected: 'console',
                    onSelect: noop,
                  ),
                ),
                ColoredBox(
                  color: c.surfaceRaised,
                  child: SizedBox(
                    height: FsSizes.tab,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: FsSpacing.s1,
                      ),
                      child: Center(
                        child: FsIconButton(
                          icon: FsIcons.panelBottom,
                          iconSize: FsSizes.iconSm,
                          size: FsIconButtonSize.small,
                          tooltip: collapsed ? 'Expand' : 'Collapse',
                          onPressed: () => onCollapsedChanged(!collapsed),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(FsSpacing.s2),
                child: Text(
                  '[hot reload] Reloaded 3 of 812 libraries in 241ms.',
                  style: FsText.monoConsole.copyWith(color: c.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: FsSpacing.s2),
    child: Row(
      spacing: FsSpacing.s4,
      children: [
        FsStatusDot(status: FsStatus.ok, label: 'Types up to date'),
        FsBadge(kind: FsBadgeKind.warning, count: 2),
        Spacer(),
        Text('x 412  y 288'),
        Text('100%'),
      ],
    ),
  );
}
