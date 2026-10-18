import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../grid.dart';

/// A 24px icon tile to hang tooltips on (PrIconButton comes next).
class _Tile extends StatelessWidget {
  const _Tile(this.icon, {this.disabled = false});

  final IconData icon;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: PrRadii.sm,
      ),
      child: Icon(
        icon,
        size: PrSizes.icon,
        color: disabled ? c.textDisabled : c.textSecondary,
      ),
    );
  }
}

class TooltipPage extends StatelessWidget {
  const TooltipPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget shown(PrTooltip tooltip) => Padding(
      padding: const EdgeInsets.all(PrSpacing.s2),
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
                const PrTooltip(
                  message: 'Move tool',
                  shortcut: SingleActivator(LogicalKeyboardKey.keyW),
                  child: _Tile(PrIcons.move),
                ),
              ),
            ]),
            GridRow('Property label', [
              shown(
                const PrTooltip(
                  message: 'position · Vector2',
                  details: [
                    'Default from code: Vector2.zero',
                    'PositionComponent.position',
                  ],
                  child: _Tile(PrIcons.info),
                ),
              ),
            ]),
            GridRow('Truncated name', [
              shown(
                const PrTooltip(
                  message: 'assets/images/characters/player_run.png',
                  monoMessage: true,
                  child: _Tile(PrIcons.image),
                ),
              ),
            ]),
            GridRow('Disabled — says why', [
              shown(
                const PrTooltip(
                  message: 'Stop',
                  details: ['Nothing is running'],
                  child: _Tile(PrIcons.stop, disabled: true),
                ),
              ),
            ]),
            GridRow('Error', [
              shown(
                const PrTooltip(
                  message: 'Expected a number from 0 to 1',
                  details: ['Press Esc to restore 0.85'],
                  error: true,
                  child: _Tile(PrIcons.alertCircle),
                ),
              ),
            ]),
          ],
        ),
        const SectionLabel(
          'Live · move along the row: after the first, no delay',
        ),
        PrTooltipGroup(
          child: Row(
            children: [
              for (final (icon, name, key) in [
                (PrIcons.pointer, 'Select tool', LogicalKeyboardKey.keyQ),
                (PrIcons.move, 'Move tool', LogicalKeyboardKey.keyW),
                (PrIcons.rotate, 'Rotate tool', LogicalKeyboardKey.keyE),
                (PrIcons.scale, 'Scale tool', LogicalKeyboardKey.keyR),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: PrTooltip(
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
