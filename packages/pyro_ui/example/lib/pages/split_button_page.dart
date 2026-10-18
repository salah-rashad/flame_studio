import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../grid.dart';

const _playWindow = SingleActivator(LogicalKeyboardKey.keyR, meta: true);
const _playDevice = SingleActivator(
  LogicalKeyboardKey.keyR,
  meta: true,
  shift: true,
);

List<PrMenuEntry<String>> _playMenu(String current) => [
  PrMenuItem(
    label: 'Play in window',
    value: 'window',
    checked: current == 'window',
    shortcut: _playWindow,
  ),
  PrMenuItem(
    label: 'Play on device…',
    value: 'device',
    checked: current == 'device',
    shortcut: _playDevice,
  ),
  PrMenuItem(
    label: 'Play from selected node',
    value: 'node',
    checked: current == 'node',
  ),
  const PrMenuSeparator(),
  const PrMenuItem(label: 'Profile mode', icon: PrIcons.zap, value: 'profile'),
];

const _exportMenu = <PrMenuEntry<String>>[
  PrMenuItem(label: 'Export for web', value: 'web', checked: true),
  PrMenuItem(label: 'Export for macOS', value: 'macos'),
  PrMenuItem(label: 'Export for Android', value: 'android'),
];

class SplitButtonPage extends StatefulWidget {
  const SplitButtonPage({super.key});

  @override
  State<SplitButtonPage> createState() => _SplitButtonPageState();
}

class _SplitButtonPageState extends State<SplitButtonPage> {
  String _play = 'window';
  String _last = '';

  static const _playLabels = {
    'window': 'Play',
    'device': 'Play on device',
    'node': 'Play from node',
  };

  @override
  Widget build(BuildContext context) {
    PrSplitButton<String> sample(bool primary, {bool enabled = true}) =>
        PrSplitButton<String>(
          label: primary ? 'Play' : 'Export',
          leading: primary ? const PrPlayGlyph(size: 14) : null,
          icon: primary ? null : PrIcons.external,
          onPressed: enabled ? () {} : null,
          menuItems: primary ? _playMenu('window') : _exportMenu,
          onSelected: noop,
          variant: primary
              ? PrButtonVariant.primary
              : PrButtonVariant.secondary,
          menuTooltip: primary ? 'Play options' : 'Export options',
        );

    Widget cell(
      bool primary, {
      Set<WidgetState> states = const {},
      String? part,
      bool enabled = true,
    }) {
      final button = sample(primary, enabled: enabled);
      return Padding(
        padding: const EdgeInsets.all(PrSpacing.s2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: states.isEmpty ? button : forced(states, button, part: part),
        ),
      );
    }

    GridRow row(String name, bool primary) => GridRow(name, [
      cell(primary),
      cell(primary, states: {WidgetState.hovered}),
      cell(primary, states: {WidgetState.hovered}, part: 'caret'),
      cell(primary, states: {WidgetState.pressed}),
      cell(primary, states: {WidgetState.focused}),
      cell(primary, states: {WidgetState.selected}, part: 'open'),
      cell(primary, enabled: false),
    ]);

    return GalleryPage(
      title: 'SplitButton',
      note:
          'Two hit targets with their own hover and pressed; the caret is '
          '20px. Divider 1px accent-pressed (primary) or border-control '
          '(secondary). Open: the caret keeps the pressed fill; the menu '
          'opens below, left aligned, the current default checked. Enter or '
          'Space runs the main action; ↓ or Alt+↓ opens the menu.',
      children: [
        StateGrid(
          columns: const [
            'Default',
            'Hover main',
            'Hover caret',
            'Pressed',
            'Focused',
            'Open',
            'Disabled',
          ],
          cellWidth: 128,
          labelWidth: 72,
          rows: [row('Primary', true), row('Secondary', false)],
        ),
        const SectionLabel('Open'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            forced(const {WidgetState.selected}, sample(true), part: 'open'),
            const SizedBox(height: PrSpacing.s1),
            forced(
              const {WidgetState.hovered},
              part: 'Play on device…',
              PrMenuPanel<String>(entries: _playMenu('window'), width: 232),
            ),
          ],
        ),
        const SectionLabel('Live'),
        PrTooltipGroup(
          child: Row(
            children: [
              PrSplitButton<String>(
                label: _playLabels[_play]!,
                leading: const PrPlayGlyph(size: 14),
                onPressed: () => setState(() => _last = 'Ran: $_play'),
                menuItems: _playMenu(_play),
                onSelected: (v) => setState(() {
                  if (_playLabels.containsKey(v)) _play = v;
                  _last = 'Chose: $v';
                }),
                tooltip: _playLabels[_play],
                shortcut: _play == 'device' ? _playDevice : _playWindow,
                menuTooltip: 'Play options',
                menuWidth: 232,
              ),
              const SizedBox(width: PrSpacing.s4),
              PrSplitButton<String>(
                label: 'Export',
                icon: PrIcons.external,
                onPressed: () => setState(() => _last = 'Ran: export'),
                menuItems: _exportMenu,
                onSelected: (v) => setState(() => _last = 'Chose: $v'),
                variant: PrButtonVariant.secondary,
                menuTooltip: 'Export options',
              ),
              const SizedBox(width: PrSpacing.s4),
              PrSplitButton<String>(
                label: 'Play',
                leading: const PrPlayGlyph(size: 14),
                onPressed: null,
                menuItems: _playMenu(_play),
                tooltip: 'Play',
                disabledReason: 'Open a scene first',
              ),
              const SizedBox(width: PrSpacing.s4),
              Text(
                _last,
                style: PrText.small.copyWith(
                  color: PrColors.of(context).textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
