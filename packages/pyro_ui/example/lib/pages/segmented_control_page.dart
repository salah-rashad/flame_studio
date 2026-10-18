import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../grid.dart';

const _tools = [
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
];

const _filters = [
  PrSegment(value: 'all', label: 'All'),
  PrSegment(value: 'info', label: 'Info', count: 12),
  PrSegment(
    value: 'warnings',
    label: 'Warnings',
    count: 2,
    countKind: PrBadgeKind.warning,
  ),
  PrSegment(
    value: 'errors',
    label: 'Errors',
    count: 1,
    countKind: PrBadgeKind.error,
  ),
];

class SegmentedControlPage extends StatefulWidget {
  const SegmentedControlPage({super.key});

  @override
  State<SegmentedControlPage> createState() => _SegmentedControlPageState();
}

class _SegmentedControlPageState extends State<SegmentedControlPage> {
  String _tool = 'move';
  String _filter = 'all';
  String _view = '2d';

  @override
  Widget build(BuildContext context) {
    // The state goes on the third segment, as in preview.html.
    Widget cell(bool text, {Set<WidgetState> states = const {}}) {
      final control = PrSegmentedControl<String>(
        segments: text ? _filters : _tools,
        selected: text ? 'all' : 'move',
        onChanged: states.contains(WidgetState.disabled) ? null : noop,
      );
      final shown = {...states}..remove(WidgetState.disabled);
      return Padding(
        padding: const EdgeInsets.all(PrSpacing.s2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: shown.isEmpty
              ? control
              : forced(shown, control, part: text ? 'Warnings' : 'Rotate'),
        ),
      );
    }

    GridRow row(String name, Set<WidgetState> states) => GridRow(name, [
      cell(false, states: states),
      cell(true, states: states),
    ]);

    return GalleryPage(
      title: 'SegmentedControl',
      note:
          'Track 24px surface-input, 1px border-control, radius-sm; segments '
          '20px with 1px gaps · text-secondary → hover surface-hover → '
          'selected accent-subtle + accent-text · inset focus ring · one Tab '
          'stop, ← → move and select. State shown on the third segment.',
      children: [
        StateGrid(
          columns: const ['Icons · tools', 'Text · filter'],
          cellWidth: 320,
          labelWidth: 88,
          rows: [
            row('Default', const {}),
            row('Hover', const {WidgetState.hovered}),
            row('Pressed', const {WidgetState.pressed}),
            row('Focused', const {WidgetState.focused}),
            row('Disabled', const {WidgetState.disabled}),
          ],
        ),
        const SectionLabel('Live'),
        PrTooltipGroup(
          child: Wrap(
            spacing: PrSpacing.s6,
            runSpacing: PrSpacing.s4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PrSegmentedControl<String>(
                segments: _tools,
                selected: _tool,
                onChanged: (v) => setState(() => _tool = v),
              ),
              PrSegmentedControl<String>(
                segments: _filters,
                selected: _filter,
                onChanged: (v) => setState(() => _filter = v),
              ),
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
        ),
      ],
    );
  }
}
