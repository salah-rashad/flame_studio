import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../grid.dart';

/// A 24px icon tile to hang tooltips on (FsIconButton comes next).
class _Tile extends StatelessWidget {
  const _Tile(this.icon, {this.disabled = false});

  final IconData icon;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: FsRadii.sm,
      ),
      child: Icon(
        icon,
        size: FsSizes.icon,
        color: disabled ? c.textDisabled : c.textSecondary,
      ),
    );
  }
}

class TooltipPage extends StatelessWidget {
  const TooltipPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget shown(FsTooltip tooltip) => Padding(
      padding: const EdgeInsets.all(FsSpacing.s2),
      child: Align(
        alignment: Alignment.topLeft,
        child: forced(const {WidgetState.hovered}, tooltip, part: 'tooltip'),
      ),
    );
    return GalleryPage(
      title: 'Tooltip',
      note:
          'Appears after 500ms hover (0ms when moving between adjacent '
          'tooltipped controls), below the anchor with a 4px gap, flips to '
          'stay on screen; hides on press or Esc. Keyboard focus shows it '
          'too, after the same delay. The grid draws them '
          'without hover; try the live row below.',
      children: [
        StateGrid(
          columns: const ['Shown'],
          cellWidth: 300,
          rows: [
            GridRow('Icon button + shortcut', [
              shown(
                const FsTooltip(
                  message: 'Move tool',
                  shortcut: SingleActivator(LogicalKeyboardKey.keyW),
                  child: _Tile(FsIcons.move),
                ),
              ),
            ]),
            GridRow('Property label', [
              shown(
                const FsTooltip(
                  message: 'position · Vector2',
                  details: [
                    'Default from code: Vector2.zero',
                    'PositionComponent.position',
                  ],
                  child: _Tile(FsIcons.info),
                ),
              ),
            ]),
            GridRow('Truncated name', [
              shown(
                const FsTooltip(
                  message: 'assets/images/characters/player_run.png',
                  monoMessage: true,
                  child: _Tile(FsIcons.image),
                ),
              ),
            ]),
            GridRow('Disabled — says why', [
              shown(
                const FsTooltip(
                  message: 'Stop',
                  details: ['Nothing is running'],
                  child: _Tile(FsIcons.stop, disabled: true),
                ),
              ),
            ]),
            GridRow('Error', [
              shown(
                const FsTooltip(
                  message: 'Expected a number from 0 to 1',
                  details: ['Press Esc to restore 0.85'],
                  error: true,
                  child: _Tile(FsIcons.alertCircle),
                ),
              ),
            ]),
          ],
        ),
        const SectionLabel(
          'Live · move along the row: after the first, no delay',
        ),
        FsTooltipGroup(
          child: Row(
            children: [
              for (final (icon, name, key) in [
                (FsIcons.pointer, 'Select tool', LogicalKeyboardKey.keyQ),
                (FsIcons.move, 'Move tool', LogicalKeyboardKey.keyW),
                (FsIcons.rotate, 'Rotate tool', LogicalKeyboardKey.keyE),
                (FsIcons.scale, 'Scale tool', LogicalKeyboardKey.keyR),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: FsTooltip(
                    message: name,
                    shortcut: SingleActivator(key),
                    child: _Tile(icon),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
