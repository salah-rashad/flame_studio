import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    final c = FsColors.of(context);

    FsToolbar main({required bool running, bool live = false}) {
      void run(bool value) {
        if (!live) return;
        setState(() {
          _running = value;
          _paused = false;
        });
      }

      return FsToolbar(
        highlighted: running,
        leading: [
          FsToolbarGroup(
            children: [
              FsIconButton(
                icon: FsIcons.undo,
                tooltip: 'Undo',
                shortcut: _cmd(LogicalKeyboardKey.keyZ),
                onPressed: () {},
              ),
              FsIconButton(
                icon: FsIcons.redo,
                tooltip: 'Redo',
                shortcut: _cmd(LogicalKeyboardKey.keyZ, shift: true),
                onPressed: () {},
              ),
            ],
          ),
          FsToolbarGroup(
            children: [
              FsSegmentedControl<String>(
                segments: const [
                  FsSegment(
                    value: 'select',
                    icon: FsIcons.pointer,
                    tooltip: 'Select',
                    shortcut: SingleActivator(LogicalKeyboardKey.keyQ),
                  ),
                  FsSegment(
                    value: 'move',
                    icon: FsIcons.move,
                    tooltip: 'Move',
                    shortcut: SingleActivator(LogicalKeyboardKey.keyW),
                  ),
                  FsSegment(
                    value: 'rotate',
                    icon: FsIcons.rotate,
                    tooltip: 'Rotate',
                    shortcut: SingleActivator(LogicalKeyboardKey.keyE),
                  ),
                  FsSegment(
                    value: 'scale',
                    icon: FsIcons.scale,
                    tooltip: 'Scale',
                    shortcut: SingleActivator(LogicalKeyboardKey.keyR),
                  ),
                ],
                selected: live ? _tool : 'move',
                onChanged: live ? (v) => setState(() => _tool = v) : noop,
              ),
            ],
          ),
          FsToolbarGroup(
            children: [
              FsToggleButton(
                icon: FsIcons.grid,
                value: live ? _grid : true,
                tooltip: 'Show grid',
                shortcut: _cmd(LogicalKeyboardKey.keyG),
                onChanged: live ? (v) => setState(() => _grid = v) : noop,
              ),
              FsToggleButton(
                icon: FsIcons.magnet,
                label: '8 px',
                value: live && _snap,
                tooltip: 'Snap to grid',
                onChanged: live ? (v) => setState(() => _snap = v) : noop,
              ),
            ],
          ),
        ],
        center: [
          FsToolbarGroup(
            children: [
              FsSplitButton<String>(
                label: running ? 'Restart' : 'Play',
                leading: const FsPlayGlyph(size: 14),
                onPressed: () => run(true),
                menuItems: const [
                  FsMenuItem(
                    label: 'Play in window',
                    value: 'window',
                    checked: true,
                  ),
                  FsMenuItem(label: 'Play on device…', value: 'device'),
                ],
                onSelected: (_) => run(true),
                tooltip: 'Play',
                shortcut: _cmd(LogicalKeyboardKey.keyR),
                menuTooltip: 'Play options',
                menuWidth: 232,
              ),
              FsIconButton(
                icon: FsIcons.pause,
                tooltip: 'Pause',
                selected: running && live && _paused,
                disabledReason: 'The game is not running',
                onPressed: running
                    ? () {
                        if (live) setState(() => _paused = !_paused);
                      }
                    : null,
              ),
              FsIconButton(
                icon: FsIcons.stepForward,
                tooltip: 'Step one frame',
                disabledReason: 'Pause the game first',
                onPressed: running && (!live || _paused) ? () {} : null,
              ),
              FsIconButton(
                icon: FsIcons.stop,
                tooltip: 'Stop',
                shortcut: _cmd(LogicalKeyboardKey.period),
                disabledReason: 'The game is not running',
                onPressed: running ? () => run(false) : null,
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
                label: 'iPhone 15',
                detail: '852×393',
                selected: true,
                onPressed: () {},
              ),
              FsStatusDot(
                status: running ? FsStatus.ok : FsStatus.idle,
                label: running ? 'Running' : 'Hot reload ready',
              ),
            ],
          ),
          FsToolbarGroup(
            children: [
              FsIconButton(
                icon: FsIcons.search,
                tooltip: 'Search',
                shortcut: _cmd(LogicalKeyboardKey.keyK),
                onPressed: () {},
              ),
              FsIconButton(
                icon: FsIcons.sliders,
                tooltip: 'Settings',
                shortcut: _cmd(LogicalKeyboardKey.comma),
                onPressed: () {},
              ),
            ],
          ),
        ],
      );
    }

    final viewport = FsToolbar(
      style: FsToolbarStyle.viewport,
      leading: [
        FsToolbarGroup(
          children: [
            FsSegmentedControl<String>(
              segments: const [
                FsSegment(value: '2d', label: '2D'),
                FsSegment(value: 'camera', label: 'Camera'),
              ],
              selected: _view,
              onChanged: (v) => setState(() => _view = v),
            ),
          ],
        ),
        FsToolbarGroup(
          children: [
            FsToggleButton(
              icon: FsIcons.hitbox,
              value: _hitboxes,
              tooltip: 'Show hitboxes',
              onChanged: (v) => setState(() => _hitboxes = v),
            ),
            FsToggleButton(
              icon: FsIcons.grid,
              value: _viewGrid,
              tooltip: 'Show grid',
              onChanged: (v) => setState(() => _viewGrid = v),
            ),
            FsToggleButton(
              icon: FsIcons.video,
              value: _cameraBounds,
              tooltip: 'Show camera bounds',
              onChanged: (v) => setState(() => _cameraBounds = v),
            ),
          ],
        ),
      ],
      trailing: [
        FsToolbarGroup(
          children: [
            Text(
              'x 412  y 288',
              style: FsText.mono.copyWith(color: c.textSecondary),
            ),
          ],
        ),
        FsToolbarGroup(
          children: [
            SizedBox(
              width: 84,
              child: FsDropdown<int>(
                size: FsFieldSize.dense,
                monoOptions: true,
                options: const [
                  FsDropdownOption(value: 50, label: '50%'),
                  FsDropdownOption(value: 100, label: '100%'),
                  FsDropdownOption(value: 200, label: '200%'),
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
          borderRadius: FsRadii.sm,
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
        FsTooltipGroup(child: box(1120, main(running: _running, live: true))),
        const SectionLabel('Running game · highlighted (accent outline)'),
        FsTooltipGroup(child: box(1120, main(running: true))),
        const SectionLabel('Viewport toolbar · 32px · surface-panel'),
        FsTooltipGroup(child: box(720, viewport)),
      ],
    );
  }
}
