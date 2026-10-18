import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../grid.dart';

SingleActivator _cmd(LogicalKeyboardKey key, {bool shift = false}) =>
    SingleActivator(key, meta: true, shift: shift);

class ToolbarPage extends StatefulWidget {
  const ToolbarPage({super.key});

  @override
  State<ToolbarPage> createState() => _ToolbarPageState();
}

class _ToolbarPageState extends State<ToolbarPage> {
  String _tool = 'move';
  bool _grid = true;
  bool _snap = false;
  bool _running = false;
  bool _paused = false;
  String _view = '2d';
  bool _hitboxes = true;
  bool _viewGrid = false;
  bool _cameraBounds = false;
  int _zoom = 100;

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);

    PrToolbar main({required bool running, bool live = false}) {
      void run(bool value) {
        if (!live) return;
        setState(() {
          _running = value;
          _paused = false;
        });
      }

      return PrToolbar(
        highlighted: running,
        leading: [
          PrToolbarGroup(
            children: [
              PrIconButton(
                icon: PrIcons.undo,
                tooltip: 'Undo',
                shortcut: _cmd(LogicalKeyboardKey.keyZ),
                onPressed: () {},
              ),
              PrIconButton(
                icon: PrIcons.redo,
                tooltip: 'Redo',
                shortcut: _cmd(LogicalKeyboardKey.keyZ, shift: true),
                onPressed: () {},
              ),
            ],
          ),
          PrToolbarGroup(
            children: [
              PrSegmentedControl<String>(
                segments: const [
                  PrSegment(
                    value: 'select',
                    icon: PrIcons.pointer,
                    tooltip: 'Select',
                    shortcut: SingleActivator(LogicalKeyboardKey.keyQ),
                  ),
                  PrSegment(
                    value: 'move',
                    icon: PrIcons.move,
                    tooltip: 'Move',
                    shortcut: SingleActivator(LogicalKeyboardKey.keyW),
                  ),
                  PrSegment(
                    value: 'rotate',
                    icon: PrIcons.rotate,
                    tooltip: 'Rotate',
                    shortcut: SingleActivator(LogicalKeyboardKey.keyE),
                  ),
                  PrSegment(
                    value: 'scale',
                    icon: PrIcons.scale,
                    tooltip: 'Scale',
                    shortcut: SingleActivator(LogicalKeyboardKey.keyR),
                  ),
                ],
                selected: live ? _tool : 'move',
                onChanged: live ? (v) => setState(() => _tool = v) : noop,
              ),
            ],
          ),
          PrToolbarGroup(
            children: [
              PrToggleButton(
                icon: PrIcons.grid,
                value: live ? _grid : true,
                tooltip: 'Show grid',
                shortcut: _cmd(LogicalKeyboardKey.keyG),
                onChanged: live ? (v) => setState(() => _grid = v) : noop,
              ),
              PrToggleButton(
                icon: PrIcons.magnet,
                label: '8 px',
                value: live && _snap,
                tooltip: 'Snap to grid',
                onChanged: live ? (v) => setState(() => _snap = v) : noop,
              ),
            ],
          ),
        ],
        center: [
          PrToolbarGroup(
            children: [
              PrSplitButton<String>(
                label: running ? 'Restart' : 'Play',
                leading: const PrPlayGlyph(size: 14),
                onPressed: () => run(true),
                menuItems: const [
                  PrMenuItem(
                    label: 'Play in window',
                    value: 'window',
                    checked: true,
                  ),
                  PrMenuItem(label: 'Play on device…', value: 'device'),
                ],
                onSelected: (_) => run(true),
                tooltip: 'Play',
                shortcut: _cmd(LogicalKeyboardKey.keyR),
                menuTooltip: 'Play options',
                menuWidth: 232,
              ),
              PrIconButton(
                icon: PrIcons.pause,
                tooltip: 'Pause',
                selected: running && live && _paused,
                disabledReason: 'The game is not running',
                onPressed: running
                    ? () {
                        if (live) setState(() => _paused = !_paused);
                      }
                    : null,
              ),
              PrIconButton(
                icon: PrIcons.stepForward,
                tooltip: 'Step one frame',
                disabledReason: 'Pause the game first',
                onPressed: running && (!live || _paused) ? () {} : null,
              ),
              PrIconButton(
                icon: PrIcons.stop,
                tooltip: 'Stop',
                shortcut: _cmd(LogicalKeyboardKey.period),
                disabledReason: 'The game is not running',
                onPressed: running ? () => run(false) : null,
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
                label: 'iPhone 15',
                detail: '852×393',
                selected: true,
                chevron: true,
                onPressed: () {},
              ),
              PrStatusDot(
                status: running ? PrStatus.ok : PrStatus.idle,
                label: running ? 'Running' : 'Hot reload ready',
              ),
            ],
          ),
          PrToolbarGroup(
            children: [
              PrIconButton(
                icon: PrIcons.search,
                tooltip: 'Search',
                shortcut: _cmd(LogicalKeyboardKey.keyK),
                onPressed: () {},
              ),
              PrIconButton(
                icon: PrIcons.sliders,
                tooltip: 'Settings',
                shortcut: _cmd(LogicalKeyboardKey.comma),
                onPressed: () {},
              ),
            ],
          ),
        ],
      );
    }

    final viewport = PrToolbar(
      style: PrToolbarStyle.viewport,
      leading: [
        PrToolbarGroup(
          children: [
            PrSegmentedControl<String>(
              segments: const [
                PrSegment(value: '2d', label: '2D'),
                PrSegment(value: 'camera', label: 'Camera'),
              ],
              selected: _view,
              onChanged: (v) => setState(() => _view = v),
            ),
          ],
        ),
        PrToolbarGroup(
          children: [
            PrToggleButton(
              icon: PrIcons.hitbox,
              value: _hitboxes,
              tooltip: 'Show hitboxes',
              onChanged: (v) => setState(() => _hitboxes = v),
            ),
            PrToggleButton(
              icon: PrIcons.grid,
              value: _viewGrid,
              tooltip: 'Show grid',
              onChanged: (v) => setState(() => _viewGrid = v),
            ),
            PrToggleButton(
              icon: PrIcons.video,
              value: _cameraBounds,
              tooltip: 'Show camera bounds',
              onChanged: (v) => setState(() => _cameraBounds = v),
            ),
          ],
        ),
      ],
      trailing: [
        PrToolbarGroup(
          children: [
            Text(
              'x 412  y 288',
              style: PrText.mono.copyWith(color: c.textSecondary),
            ),
          ],
        ),
        PrToolbarGroup(
          children: [
            SizedBox(
              width: 84,
              child: PrDropdown<int>(
                size: PrFieldSize.dense,
                monoOptions: true,
                options: const [
                  PrDropdownOption(value: 50, label: '50%'),
                  PrDropdownOption(value: 100, label: '100%'),
                  PrDropdownOption(value: 200, label: '200%'),
                ],
                value: _zoom,
                onChanged: (v) => setState(() => _zoom = v),
              ),
            ),
          ],
        ),
      ],
    );

    Widget box(double width, Widget child) => ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: Container(
        decoration: BoxDecoration(
          color: c.surfacePanel,
          border: Border.all(color: c.borderSubtle),
          borderRadius: PrRadii.sm,
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );

    return GalleryPage(
      title: 'Toolbar',
      note:
          'Groups: history · tool mode (segmented) · view toggles — Play '
          'cluster centred — target device · runtime status · global. Groups '
          'are separated by a 1px × 16px border-subtle divider; buttons '
          'inside a group sit 2px apart. One Tab stop; ← → move between the '
          'controls (Home and End to the ends), Tab leaves.',
      children: [
        const SectionLabel('Main toolbar · 32px · surface-raised (live)'),
        PrTooltipGroup(child: box(1120, main(running: _running, live: true))),
        const SectionLabel('Running game · highlighted (accent outline)'),
        PrTooltipGroup(child: box(1120, main(running: true))),
        const SectionLabel('Viewport toolbar · 32px · surface-panel'),
        PrTooltipGroup(child: box(720, viewport)),
      ],
    );
  }
}
