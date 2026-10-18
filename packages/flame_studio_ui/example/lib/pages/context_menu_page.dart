import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../grid.dart';

const _cmd = SingleActivator(LogicalKeyboardKey.keyD, meta: true);

List<FsMenuEntry<String>> _nodeMenu() => const [
  FsMenuHeader('Player'),
  FsMenuItem(
    label: 'Rename',
    value: 'rename',
    shortcut: SingleActivator(LogicalKeyboardKey.enter),
  ),
  FsMenuItem(
    label: 'Duplicate',
    icon: FsIcons.copy,
    value: 'duplicate',
    shortcut: _cmd,
  ),
  FsMenuItem(
    label: 'Copy',
    value: 'copy',
    shortcut: SingleActivator(LogicalKeyboardKey.keyC, meta: true),
  ),
  FsMenuItem(
    label: 'Paste as child',
    value: 'paste',
    enabled: false,
    shortcut: SingleActivator(LogicalKeyboardKey.keyV, meta: true, shift: true),
  ),
  FsMenuSeparator(),
  FsMenuItem(label: 'Add child', icon: FsIcons.plus, submenu: _addMenu),
  FsMenuItem(label: 'Convert to prefab', icon: FsIcons.box, value: 'prefab'),
  FsMenuItem(
    label: 'Show in viewport',
    icon: FsIcons.crosshair,
    value: 'frame',
    shortcut: SingleActivator(LogicalKeyboardKey.keyF),
  ),
  FsMenuSeparator(),
  FsMenuItem(
    label: 'Visible',
    value: 'visible',
    checked: true,
    shortcut: SingleActivator(LogicalKeyboardKey.keyH, alt: true),
  ),
  FsMenuItem(
    label: 'Locked',
    value: 'locked',
    shortcut: SingleActivator(LogicalKeyboardKey.keyL, alt: true),
  ),
  FsMenuSeparator(),
  FsMenuItem(
    label: 'Delete',
    icon: FsIcons.trash,
    value: 'delete',
    destructive: true,
    shortcut: SingleActivator(LogicalKeyboardKey.backspace),
  ),
];

const _addMenu = <FsMenuEntry<String>>[
  FsMenuItem(label: 'PositionComponent', icon: FsIcons.box, value: 'position'),
  FsMenuItem(label: 'SpriteComponent', icon: FsIcons.image, value: 'sprite'),
  FsMenuItem(
    label: 'SpriteAnimationComponent',
    icon: FsIcons.film,
    value: 'animation',
  ),
  FsMenuItem(label: 'TextComponent', icon: FsIcons.type, value: 'text'),
  FsMenuItem(
    label: 'Collision',
    submenu: [
      FsMenuItem(label: 'RectangleHitbox', icon: FsIcons.hitbox, value: 'rect'),
      FsMenuItem(label: 'CircleHitbox', icon: FsIcons.hitbox, value: 'circle'),
    ],
  ),
  FsMenuSeparator(),
  FsMenuItem(
    label: 'Search components…',
    icon: FsIcons.search,
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
    final c = FsColors.of(context);
    Widget force(String label, Set<WidgetState> states, Widget child) =>
        FsDebugStates(part: label, states: states, child: child);
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
            }, FsMenuPanel<String>(entries: _nodeMenu())),
            Padding(
              padding: const EdgeInsets.only(top: 158),
              child: force(
                'SpriteComponent',
                const {WidgetState.hovered},
                const FsMenuPanel<String>(entries: _addMenu, width: 232),
              ),
            ),
            const SizedBox(width: FsSpacing.s6),
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
                      const FsMenuPanel<String>(
                        entries: [
                          FsMenuItem(
                            label: 'Default',
                            icon: FsIcons.copy,
                            shortcut: _cmd,
                          ),
                          FsMenuItem(
                            label: 'Hover / keyboard focus',
                            icon: FsIcons.copy,
                            shortcut: _cmd,
                          ),
                          FsMenuItem(
                            label: 'Pressed',
                            icon: FsIcons.copy,
                            shortcut: _cmd,
                          ),
                          FsMenuItem(label: 'Checked', checked: true),
                          FsMenuItem(
                            label: 'Disabled',
                            icon: FsIcons.copy,
                            shortcut: _cmd,
                            enabled: false,
                          ),
                          FsMenuItem(
                            label: 'Destructive',
                            icon: FsIcons.trash,
                            destructive: true,
                          ),
                          FsMenuItem(
                            label: 'Destructive · hover',
                            icon: FsIcons.trash,
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
              child: FsContextMenuRegion<String>(
                entries: _nodeMenu,
                onSelected: _chose,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: c.borderSubtle),
                    borderRadius: FsRadii.sm,
                  ),
                  child: Center(
                    child: Text(
                      'Right-click here',
                      style: FsText.small.copyWith(color: c.textSecondary),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: FsSpacing.s4),
            FsMenuButton<String>(
              entries: _nodeMenu(),
              onSelected: _chose,
              builder: (context, controller) => FsIconButton(
                icon: FsIcons.more,
                tooltip: 'More',
                selected: controller.isOpen,
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
              ),
            ),
            const SizedBox(width: FsSpacing.s4),
            Text(
              'Chosen: $_last',
              style: FsText.mono.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}
