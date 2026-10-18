import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';

import '../grid.dart';

class BadgePage extends StatefulWidget {
  const BadgePage({super.key});

  @override
  State<BadgePage> createState() => _BadgePageState();
}

class _BadgePageState extends State<BadgePage> {
  int _target = 0;

  @override
  Widget build(BuildContext context) {
    Widget chip(
      IconData icon,
      String label,
      String detail, {
      Set<WidgetState> states = const {},
      bool enabled = true,
      bool selected = false,
      bool error = false,
    }) {
      final widget = FsDeviceChip(
        icon: icon,
        label: label,
        detail: error ? 'offline' : detail,
        selected: selected,
        error: error,
        onPressed: enabled ? () {} : null,
      );
      return Padding(
        padding: const EdgeInsets.all(FsSpacing.s2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: states.isEmpty ? widget : forced(states, widget),
        ),
      );
    }

    GridRow row(String name, IconData icon, String label, String detail) =>
        GridRow(name, [
          chip(icon, label, detail),
          chip(icon, label, detail, states: {WidgetState.hovered}),
          chip(icon, label, detail, states: {WidgetState.pressed}),
          chip(icon, label, detail, states: {WidgetState.focused}),
          chip(icon, label, detail, enabled: false),
          chip(icon, label, detail, selected: true),
          chip(icon, label, detail, error: true),
        ]);

    return GalleryPage(
      title: 'Badge · DeviceChip',
      note:
          'Status badges always carry an icon or a word: colour alone never '
          'carries the meaning.',
      children: [
        const SectionLabel('Badges & pills · 16px · caption'),
        const Wrap(
          spacing: FsSpacing.s2,
          children: [
            FsBadge(kind: FsBadgeKind.warning, count: 2),
            FsBadge(kind: FsBadgeKind.error, count: 1),
            FsBadge(kind: FsBadgeKind.missing, label: 'Missing'),
            FsBadge(kind: FsBadgeKind.prefab, label: 'Prefab'),
            FsBadge(kind: FsBadgeKind.info, label: 'Running'),
            FsBadge(kind: FsBadgeKind.neutral, count: 24),
            FsBadge(kind: FsBadgeKind.accent, label: 'Modified'),
            FsBadge(kind: FsBadgeKind.success, label: 'Saved'),
            FsBadge(kind: FsBadgeKind.warning, count: 3, pill: true),
          ],
        ),
        StateGrid(
          columns: const [
            'Default',
            'Hover',
            'Pressed',
            'Focused',
            'Disabled',
            'Selected',
            'Error',
          ],
          cellWidth: 176,
          labelWidth: 90,
          rows: [
            row('Device chip', FsIcons.smartphone, 'iPhone 15', '852×393'),
            row('Desktop', FsIcons.monitor, 'Window', '1280×720'),
          ],
        ),
        const SectionLabel('Live · pick a target'),
        Wrap(
          spacing: FsSpacing.s2,
          children: [
            for (final (i, (icon, name, detail)) in const [
              (FsIcons.smartphone, 'iPhone 15', '852×393'),
              (FsIcons.monitor, 'Window', '1280×720'),
              (FsIcons.smartphone, 'Pixel 8', '915×412'),
            ].indexed)
              FsDeviceChip(
                icon: icon,
                label: name,
                detail: detail,
                selected: i == _target,
                onPressed: () => setState(() => _target = i),
              ),
          ],
        ),
      ],
    );
  }
}
