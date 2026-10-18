import 'package:flutter/material.dart';
import 'package:pyro_ui/pyro_ui.dart';

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
  PrShellSizes _sizes = PrShellSizes.standard;
  PrShellSizes? _saved;
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    final window = _windows[_window];
    final shell = PrEditorShell(
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
          padding: const EdgeInsets.all(PrSpacing.s4),
          child: Row(
            spacing: PrSpacing.s4,
            children: [
              Text(
                'EditorShell',
                style: PrText.title.copyWith(color: c.textPrimary),
              ),
              PrSegmentedControl<String>(
                segments: [
                  for (final name in _windows.keys)
                    PrSegment(value: name, label: name),
                ],
                selected: _window,
                onChanged: (v) => setState(() => _window = v),
              ),
              PrButton(
                label: 'Reset sizes',
                variant: PrButtonVariant.ghost,
                onPressed: () => setState(() {
                  _sizes = PrShellSizes.standard;
                  _collapsed = false;
                }),
              ),
              Expanded(
                child: Text(
                  'Drag the seams; a window too small for the docks shrinks '
                  'them in layout only. Saved on drag end: '
                  '${_saved ?? 'nothing yet'}',
                  style: PrText.small.copyWith(color: c.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              PrSpacing.s4,
              0,
              PrSpacing.s4,
              PrSpacing.s4,
            ),
            child: _Desktop(
              child: window == null
                  ? Padding(
                      padding: const EdgeInsets.all(_Desktop.inset),
                      child: _MacWindow(child: shell),
                    )
                  : FittedBox(
                      child: Padding(
                        padding: const EdgeInsets.all(_Desktop.inset),
                        child: SizedBox.fromSize(
                          size: window,
                          child: _MacWindow(child: shell),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A wallpaper-like backdrop that sets the window apart from the gallery,
/// whose surfaces are close to the shell's `bg-app`.
class _Desktop extends StatelessWidget {
  const _Desktop({required this.child});

  /// The room around the window, for its shadow.
  static const double inset = PrSpacing.s8;

  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: PrRadii.lg,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF353A4D), Color(0xFF4D3429)],
        ),
      ),
      child: child,
    ),
  );
}

/// A macOS window frame: rounded corners, the dark-mode outline and inner
/// highlight, the window shadow, and the traffic lights drawn in the
/// shell's title-bar inset (a real window gets them from the runner).
class _MacWindow extends StatelessWidget {
  const _MacWindow({required this.child});

  static const _radius = BorderRadius.all(Radius.circular(10));

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      borderRadius: _radius,
      boxShadow: [
        BoxShadow(color: Color(0xCC000000), spreadRadius: 1),
        BoxShadow(
          color: Color(0x80000000),
          offset: Offset(0, 20),
          blurRadius: 60,
        ),
      ],
    ),
    position: DecorationPosition.background,
    child: ClipRRect(
      borderRadius: _radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: _radius,
          border: Border.all(color: const Color(0x1FFFFFFF)),
        ),
        position: DecorationPosition.foreground,
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            // Centred in the 38px title bar, inside its 78px inset.
            const Positioned(left: 20, top: 13, child: _TrafficLights()),
          ],
        ),
      ),
    ),
  );
}

class _TrafficLights extends StatelessWidget {
  const _TrafficLights();

  static const _lights = [
    (Color(0xFFFF5F57), Color(0xFFE0443E)),
    (Color(0xFFFEBC2E), Color(0xFFDEA123)),
    (Color(0xFF28C840), Color(0xFF1AAB29)),
  ];

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 8,
    children: [
      for (final (fill, edge) in _lights)
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: edge, width: 0.5),
          ),
        ),
    ],
  );
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
  Widget build(BuildContext context) => const PrToolbar(
    leading: [
      PrToolbarGroup(
        children: [
          PrIconButton(icon: PrIcons.undo, tooltip: 'Undo', onPressed: noop),
          PrIconButton(
            icon: PrIcons.redo,
            tooltip: 'Redo',
            disabledReason: 'Nothing to redo',
            onPressed: null,
          ),
        ],
      ),
      PrToolbarGroup(
        children: [
          PrSegmentedControl<String>(
            segments: [
              PrSegment(
                value: 'select',
                icon: PrIcons.pointer,
                tooltip: 'Select',
              ),
              PrSegment(value: 'move', icon: PrIcons.move, tooltip: 'Move'),
              PrSegment(
                value: 'rotate',
                icon: PrIcons.rotate,
                tooltip: 'Rotate',
              ),
              PrSegment(value: 'scale', icon: PrIcons.scale, tooltip: 'Scale'),
            ],
            selected: 'move',
            onChanged: noop,
          ),
        ],
      ),
      PrToolbarGroup(
        children: [
          PrToggleButton(
            icon: PrIcons.magnet,
            label: '8 px',
            value: true,
            tooltip: 'Snap to grid',
            onChanged: noop,
          ),
        ],
      ),
    ],
    center: [
      PrToolbarGroup(
        children: [
          PrSplitButton<String>(
            label: 'Play',
            leading: PrPlayGlyph(size: 14),
            onPressed: noop,
            menuItems: [PrMenuItem(label: 'Play in window', value: 'window')],
            onSelected: noop,
            tooltip: 'Play',
            menuTooltip: 'Play options',
          ),
          PrIconButton(
            icon: PrIcons.stop,
            tooltip: 'Stop',
            disabledReason: 'The game is not running',
            onPressed: null,
          ),
        ],
      ),
    ],
    trailing: [
      PrToolbarGroup(
        spacing: PrSpacing.s2,
        children: [
          PrDeviceChip(
            icon: PrIcons.smartphone,
            label: 'iPhone 16 Simulator',
            selected: true,
            onPressed: noop,
          ),
          PrStatusDot(status: PrStatus.idle, label: 'Hot reload ready'),
        ],
      ),
    ],
  );
}

class _ScenePanel extends StatelessWidget {
  const _ScenePanel();

  @override
  Widget build(BuildContext context) => PrPanel(
    title: 'Scene',
    icon: PrIcons.listTree,
    actions: [
      const PrIconButton(
        icon: PrIcons.plus,
        iconSize: PrSizes.iconSm,
        size: PrIconButtonSize.small,
        tooltip: 'Add node',
        onPressed: noop,
      ),
    ],
    body: ListView(
      padding: const EdgeInsets.symmetric(vertical: PrSpacing.s1),
      children: [
        const PrTreeRow<String>(
          depth: 0,
          name: 'Level1',
          icon: PrIcons.layers,
          hasChildren: true,
          expanded: true,
          onTap: noop,
        ),
        const PrTreeRow<String>(
          depth: 1,
          name: 'Player',
          icon: PrIcons.image,
          selected: true,
          onTap: noop,
        ),
        const PrTreeRow<String>(
          depth: 1,
          name: 'Camera',
          icon: PrIcons.video,
          onTap: noop,
        ),
        const PrTreeRow<String>(
          depth: 1,
          name: 'Enemies',
          icon: PrIcons.layers,
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
    final c = PrColors.of(context);
    return ColoredBox(
      color: c.surfacePanel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PrTabs<String>(
            tabs: [
              PrTab(value: 'level', label: 'level_1.scene', icon: PrIcons.file),
              PrTab(
                value: 'menu',
                label: 'main_menu.scene',
                icon: PrIcons.file,
                dirty: true,
              ),
            ],
            selected: 'level',
            onSelect: noop,
            onClose: noop,
            closeTooltip: 'Close',
          ),
          const PrToolbar(
            style: PrToolbarStyle.viewport,
            leading: [
              PrToolbarGroup(
                children: [
                  PrToggleButton(
                    icon: PrIcons.grid,
                    value: true,
                    tooltip: 'Show grid',
                    onChanged: noop,
                  ),
                  PrToggleButton(
                    icon: PrIcons.hitbox,
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
  Widget build(BuildContext context) => PrPanel(
    title: 'Inspector',
    icon: PrIcons.sliders,
    body: ListView(
      children: [
        const PrSectionHeader(
          title: 'PositionComponent',
          expanded: true,
          onExpandedChanged: noop,
        ),
        const PrPropertyList(
          children: [
            PrVector2Property(
              label: 'position',
              x: 412.5,
              y: 288,
              onChanged: noop,
              onCommit: noop,
            ),
            PrNumberProperty(
              label: 'angle',
              value: 0,
              onChanged: noop,
              onCommit: noop,
            ),
            PrBoolProperty(label: 'debugMode', value: false, onChanged: noop),
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
    final c = PrColors.of(context);
    return PrPanelFocus(
      child: ColoredBox(
        color: c.surfacePanel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: PrTabs<String>(
                    style: PrTabsStyle.dock,
                    tabs: [
                      PrTab(
                        value: 'console',
                        label: 'Console',
                        icon: PrIcons.terminal,
                      ),
                      PrTab(
                        value: 'assets',
                        label: 'Assets',
                        icon: PrIcons.folder,
                      ),
                    ],
                    selected: 'console',
                    onSelect: noop,
                  ),
                ),
                ColoredBox(
                  color: c.surfaceRaised,
                  child: SizedBox(
                    height: PrSizes.tab,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: PrSpacing.s1,
                      ),
                      child: Center(
                        child: PrIconButton(
                          icon: PrIcons.panelBottom,
                          iconSize: PrSizes.iconSm,
                          size: PrIconButtonSize.small,
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
                padding: const EdgeInsets.all(PrSpacing.s2),
                child: Text(
                  '[hot reload] Reloaded 3 of 812 libraries in 241ms.',
                  style: PrText.monoConsole.copyWith(color: c.textSecondary),
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
    padding: EdgeInsets.symmetric(horizontal: PrSpacing.s2),
    child: Row(
      spacing: PrSpacing.s4,
      children: [
        PrStatusDot(status: PrStatus.ok, label: 'Types up to date'),
        PrBadge(kind: PrBadgeKind.warning, count: 2),
        Spacer(),
        Text('x 412  y 288'),
        Text('100%'),
      ],
    ),
  );
}
