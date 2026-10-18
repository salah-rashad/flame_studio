import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../grid.dart';

const _tools = [
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
];

const _filters = [
  FsSegment(value: 'all', label: 'All'),
  FsSegment(value: 'info', label: 'Info', count: 12),
  FsSegment(
    value: 'warnings',
    label: 'Warnings',
    count: 2,
    countKind: FsBadgeKind.warning,
  ),
  FsSegment(
    value: 'errors',
    label: 'Errors',
    count: 1,
    countKind: FsBadgeKind.error,
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
      final control = FsSegmentedControl<String>(
        segments: text ? _filters : _tools,
        selected: text ? 'all' : 'move',
        onChanged: states.contains(WidgetState.disabled) ? null : noop,
      );
      final shown = {...states}..remove(WidgetState.disabled);
      return Padding(
        padding: const EdgeInsets.all(FsSpacing.s2),
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
        FsTooltipGroup(
          child: Wrap(
            spacing: FsSpacing.s6,
            runSpacing: FsSpacing.s4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FsSegmentedControl<String>(
                segments: _tools,
                selected: _tool,
                onChanged: (v) => setState(() => _tool = v),
              ),
              FsSegmentedControl<String>(
                segments: _filters,
                selected: _filter,
                onChanged: (v) => setState(() => _filter = v),
              ),
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
        ),
      ],
    );
  }
}
