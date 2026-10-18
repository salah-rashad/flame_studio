import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';

import '../grid.dart';

const _bold = TextStyle(fontWeight: FontWeight.w600);

FsBanner _prefab({VoidCallback? onPressed}) => FsBanner(
  kind: FsStatusKind.info,
  message: const TextSpan(
    children: [
      TextSpan(text: 'Prefab instance.', style: _bold),
      TextSpan(text: ' Changes here override player.prefab.'),
    ],
  ),
  action: FsBannerAction(label: 'Open prefab', onPressed: onPressed ?? noop),
);

FsBanner _overrides({VoidCallback? onDismiss}) => FsBanner(
  kind: FsStatusKind.warning,
  message: const TextSpan(
    children: [
      TextSpan(text: '2 overrides', style: _bold),
      TextSpan(text: ' differ from the prefab.'),
    ],
  ),
  action: const FsBannerAction(label: 'Review', onPressed: noop),
  onDismiss: onDismiss ?? noop,
  dismissTooltip: 'Dismiss',
);

FsBanner _missing() => const FsBanner(
  kind: FsStatusKind.error,
  message: TextSpan(
    children: [
      TextSpan(text: 'hurtSound', style: _bold),
      TextSpan(text: ' points to '),
      TextSpan(text: 'assets/audio/hurt.wav', style: FsText.mono),
      TextSpan(text: ', which no longer exists.'),
    ],
  ),
  action: FsBannerAction(label: 'Locate…', onPressed: noop),
);

FsBanner _migrated({VoidCallback? onDismiss}) => FsBanner(
  kind: FsStatusKind.success,
  message: const TextSpan(text: 'Scene migrated to the current format.'),
  onDismiss: onDismiss ?? noop,
  dismissTooltip: 'Dismiss',
);

class BannerPage extends StatefulWidget {
  const BannerPage({super.key});

  @override
  State<BannerPage> createState() => _BannerPageState();
}

class _BannerPageState extends State<BannerPage> {
  bool _showOverrides = true;
  bool _showMigrated = true;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    Widget sized(Widget banner) => SizedBox(width: 360, child: banner);
    Widget cell(Widget banner) =>
        Padding(padding: const EdgeInsets.all(FsSpacing.s2), child: banner);

    GridRow row(String part, String name) => GridRow(name, [
      for (final states in const [
        <WidgetState>{},
        {WidgetState.hovered},
        {WidgetState.pressed},
        {WidgetState.focused},
      ])
        cell(forced(states, _overrides(), part: part)),
    ]);

    return GalleryPage(
      title: 'Banner',
      note:
          'Inline in a panel, full panel width minus 8px margins. One '
          'sentence; bold the subject. At most one action plus dismiss. '
          'Banners describe a state that persists until fixed — use a toast '
          'for events.',
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: FsSpacing.s4,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: FsSpacing.s4,
              children: [sized(_prefab()), sized(_overrides())],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: FsSpacing.s4,
              children: [sized(_missing()), sized(_migrated())],
            ),
          ],
        ),
        StateGrid(
          columns: const ['Default', 'Hover', 'Pressed', 'Focused'],
          cellWidth: 360,
          labelWidth: 90,
          rows: [row('action', 'Action'), row('dismiss', 'Dismiss')],
        ),
        const SectionLabel('Live · inside a panel body, 8px margins'),
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: c.surfacePanel,
            border: Border.all(color: c.borderSubtle),
            borderRadius: FsRadii.sm,
          ),
          padding: const EdgeInsets.all(FsSpacing.s2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: FsSpacing.s2,
            children: [
              _prefab(onPressed: () {}),
              if (_showOverrides)
                _overrides(
                  onDismiss: () => setState(() => _showOverrides = false),
                ),
              if (_showMigrated)
                _migrated(
                  onDismiss: () => setState(() => _showMigrated = false),
                ),
              if (!_showOverrides || !_showMigrated)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FsButton(
                    label: 'Bring them back',
                    variant: FsButtonVariant.ghost,
                    onPressed: () => setState(() {
                      _showOverrides = true;
                      _showMigrated = true;
                    }),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
