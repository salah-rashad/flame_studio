import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../grid.dart';

const _cmd = SingleActivator(LogicalKeyboardKey.keyD, meta: true);

List<PrMenuEntry<String>> _nodeMenu() => const [
  PrMenuHeader('Player'),
  PrMenuItem(
    label: 'Rename',
    value: 'rename',
    shortcut: SingleActivator(LogicalKeyboardKey.enter),
  ),
  PrMenuItem(
    label: 'Duplicate',
    icon: PrIcons.copy,
    value: 'duplicate',
    shortcut: _cmd,
  ),
  PrMenuItem(
    label: 'Copy',
    value: 'copy',
    shortcut: SingleActivator(LogicalKeyboardKey.keyC, meta: true),
  ),
  PrMenuItem(
    label: 'Paste as child',
    value: 'paste',
    enabled: false,
    shortcut: SingleActivator(LogicalKeyboardKey.keyV, meta: true, shift: true),
  ),
  PrMenuSeparator(),
  PrMenuItem(label: 'Add child', icon: PrIcons.plus, submenu: _addMenu),
  PrMenuItem(label: 'Convert to prefab', icon: PrIcons.box, value: 'prefab'),
  PrMenuItem(
    label: 'Show in viewport',
    icon: PrIcons.crosshair,
    value: 'frame',
    shortcut: SingleActivator(LogicalKeyboardKey.keyF),
  ),
  PrMenuSeparator(),
  PrMenuItem(
    label: 'Visible',
    value: 'visible',
    checked: true,
    shortcut: SingleActivator(LogicalKeyboardKey.keyH, alt: true),
  ),
  PrMenuItem(
    label: 'Locked',
    value: 'locked',
    shortcut: SingleActivator(LogicalKeyboardKey.keyL, alt: true),
  ),
  PrMenuSeparator(),
  PrMenuItem(
    label: 'Delete',
    icon: PrIcons.trash,
    value: 'delete',
    destructive: true,
    shortcut: SingleActivator(LogicalKeyboardKey.backspace),
  ),
];

const _addMenu = <PrMenuEntry<String>>[
  PrMenuItem(label: 'PositionComponent', icon: PrIcons.box, value: 'position'),
  PrMenuItem(label: 'SpriteComponent', icon: PrIcons.image, value: 'sprite'),
  PrMenuItem(
    label: 'SpriteAnimationComponent',
    icon: PrIcons.film,
    value: 'animation',
  ),
  PrMenuItem(label: 'TextComponent', icon: PrIcons.type, value: 'text'),
  PrMenuItem(
    label: 'Collision',
    submenu: [
      PrMenuItem(label: 'RectangleHitbox', icon: PrIcons.hitbox, value: 'rect'),
      PrMenuItem(label: 'CircleHitbox', icon: PrIcons.hitbox, value: 'circle'),
    ],
  ),
  PrMenuSeparator(),
  PrMenuItem(
    label: 'Search components…',
    icon: PrIcons.search,
    value: 'search',
    shortcut: SingleActivator(LogicalKeyboardKey.keyK, meta: true),
  ),
];

class ContextMenuPage extends StatefulWidget {
  const ContextMenuPage({super.key});

  @override
  State<ContextMenuPage> createState() => _ContextMenuPageState();
}

class _ContextMenuPageState extends State<ContextMenuPage> {
  String _last = 'nothing yet';

  void _chose(String value) => setState(() => _last = value);

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    Widget force(String label, Set<WidgetState> states, Widget child) =>
        PrDebugStates(part: label, states: states, child: child);
    return GalleryPage(
      title: 'ContextMenu',
      note:
          '24px items, a 16px icon column always reserved, shortcuts right '
          'in text-secondary. Hover and keyboard focus look the same. '
          'Submenus open after 150ms of hover or →; ← and Esc close one level.',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            force('Add child', const {
              WidgetState.selected,
            }, PrMenuPanel<String>(entries: _nodeMenu())),
            Padding(
              padding: const EdgeInsets.only(top: 158),
              child: force(
                'SpriteComponent',
                const {WidgetState.hovered},
                const PrMenuPanel<String>(entries: _addMenu, width: 232),
              ),
            ),
            const SizedBox(width: PrSpacing.s6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Item states'),
                force(
                  'Hover / keyboard focus',
                  const {WidgetState.hovered},
                  force(
                    'Pressed',
                    const {WidgetState.pressed},
                    force(
                      'Destructive · hover',
                      const {WidgetState.hovered},
                      const PrMenuPanel<String>(
                        entries: [
                          PrMenuItem(
                            label: 'Default',
                            icon: PrIcons.copy,
                            shortcut: _cmd,
                          ),
                          PrMenuItem(
                            label: 'Hover / keyboard focus',
                            icon: PrIcons.copy,
                            shortcut: _cmd,
                          ),
                          PrMenuItem(
                            label: 'Pressed',
                            icon: PrIcons.copy,
                            shortcut: _cmd,
                          ),
                          PrMenuItem(label: 'Checked', checked: true),
                          PrMenuItem(
                            label: 'Disabled',
                            icon: PrIcons.copy,
                            shortcut: _cmd,
                            enabled: false,
                          ),
                          PrMenuItem(
                            label: 'Destructive',
                            icon: PrIcons.trash,
                            destructive: true,
                          ),
                          PrMenuItem(
                            label: 'Destructive · hover',
                            icon: PrIcons.trash,
                            destructive: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SectionLabel(
          'Live · right-click the box, or use the More button',
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 360,
              height: 120,
              child: PrContextMenuRegion<String>(
                entries: _nodeMenu,
                onSelected: _chose,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: c.borderSubtle),
                    borderRadius: PrRadii.sm,
                  ),
                  child: Center(
                    child: Text(
                      'Right-click here',
                      style: PrText.small.copyWith(color: c.textSecondary),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: PrSpacing.s4),
            PrMenuButton<String>(
              entries: _nodeMenu(),
              onSelected: _chose,
              builder: (context, controller) => PrIconButton(
                icon: PrIcons.more,
                tooltip: 'More',
                selected: controller.isOpen,
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
              ),
            ),
            const SizedBox(width: PrSpacing.s4),
            Text(
              'Chosen: $_last',
              style: PrText.mono.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}
