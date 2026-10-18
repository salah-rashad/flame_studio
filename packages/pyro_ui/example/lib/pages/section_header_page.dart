import 'package:flutter/material.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../grid.dart';

class SectionHeaderPage extends StatelessWidget {
  const SectionHeaderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final menu = <PrMenuEntry<void>>[
      PrMenuItem(label: 'Reset', onSelected: () {}),
      PrMenuItem(label: 'Copy values', onSelected: () {}),
      const PrMenuSeparator(),
      PrMenuItem(label: 'Remove', destructive: true, onSelected: () {}),
    ];
    Widget header({
      required bool expanded,
      Set<WidgetState> states = const {},
      String title = 'SpriteAnimationComponent',
      IconData icon = PrIcons.film,
      String? subtitle,
      bool enabled = true,
      bool error = false,
    }) => forced(
      states,
      PrSectionHeader(
        title: title,
        icon: icon,
        subtitle: subtitle,
        expanded: expanded,
        onExpandedChanged: noop,
        enabled: enabled,
        onEnabledChanged: noop,
        actions: [
          PrIconButton(
            icon: PrIcons.info,
            iconSize: PrSizes.iconSm,
            size: PrIconButtonSize.small,
            tooltip: 'Help',
            onPressed: () {},
          ),
        ],
        menu: menu,
        menuTooltip: 'More',
        error: error,
      ),
    );
    GridRow row(
      String label, {
      Set<WidgetState> states = const {},
      String title = 'SpriteAnimationComponent',
      String? subtitle,
      bool enabled = true,
      bool error = false,
    }) => GridRow(label, [
      for (final expanded in const [true, false])
        header(
          expanded: expanded,
          states: states,
          title: title,
          subtitle: subtitle,
          enabled: enabled,
          error: error,
        ),
    ]);

    return GalleryPage(
      title: 'SectionHeader',
      note:
          '24px · surface-raised, 1px bg-app top, border-subtle bottom · '
          'title in section · hover surface-hover · keyboard focus inset '
          'ring · disabled component: title and icon text-disabled, '
          'properties still editable · error: alert-circle in error, the '
          'subtitle says why. Click, Space or Enter toggles; Alt-click '
          'toggles every section; the checkbox enables the component; the '
          'More menu holds Reset, Copy values, Remove.',
      children: [
        StateGrid(
          columns: const ['Expanded', 'Collapsed'],
          labelWidth: 72,
          rows: [
            row('Default'),
            row('Hover', states: const {WidgetState.hovered}),
            row('Pressed', states: const {WidgetState.pressed}),
            row('Focused', states: const {WidgetState.focused}),
            row(
              'Disabled',
              title: 'SpriteComponent',
              subtitle: 'off',
              enabled: false,
            ),
            row(
              'Error',
              title: 'PlayerController',
              subtitle: 'compile error',
              error: true,
            ),
          ],
        ),
        const SectionLabel(
          'Live: click to collapse (150ms), Alt-click toggles all, the '
          'checkbox disables the component',
        ),
        const SampleBox(width: 320, child: _LiveInspector()),
      ],
    );
  }
}

class _Section {
  _Section(this.title, this.icon, this.properties);

  final String title;
  final IconData icon;
  final List<String> properties;
  bool expanded = true;
  bool enabled = true;
}

class _LiveInspector extends StatefulWidget {
  const _LiveInspector();

  @override
  State<_LiveInspector> createState() => _LiveInspectorState();
}

class _LiveInspectorState extends State<_LiveInspector> {
  final _sections = [
    _Section('PositionComponent', PrIcons.move, ['priority', 'angle']),
    _Section('SpriteComponent', PrIcons.image, ['opacity']),
    _Section('PlayerController', PrIcons.fileCode, ['speed', 'jumpHeight']),
  ];
  final _values = <String, double>{
    'priority': 10,
    'angle': 0,
    'opacity': 1,
    'speed': 180,
    'jumpHeight': 64,
  };

  void _toggleAll() => setState(() {
    final open = !_sections.every((s) => s.expanded);
    for (final s in _sections) {
      s.expanded = open;
    }
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in _sections) ...[
          PrSectionHeader(
            title: s.title,
            icon: s.icon,
            subtitle: s.enabled ? null : 'off',
            expanded: s.expanded,
            onExpandedChanged: (v) => setState(() => s.expanded = v),
            onToggleAll: _toggleAll,
            enabled: s.enabled,
            onEnabledChanged: (v) => setState(() => s.enabled = v),
            enabledLabel: 'Enabled',
            menu: [
              PrMenuItem(
                label: 'Reset',
                onSelected: () => setState(() {
                  for (final p in s.properties) {
                    _values[p] = 0;
                  }
                }),
              ),
            ],
            menuTooltip: 'More',
          ),
          PrCollapsible(
            expanded: s.expanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: PrPropertyList(
                children: [
                  for (final p in s.properties)
                    PrNumberProperty(
                      label: p,
                      value: _values[p],
                      onChanged: (v) => setState(() => _values[p] = v),
                      onCommit: (v) => setState(() => _values[p] = v),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
