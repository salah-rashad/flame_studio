import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pyro/app/app.dart';
import 'package:pyro_runtime/pyro_runtime.dart';
import 'package:pyro_ui/pyro_ui.dart';

import 'geometry.dart';
import 'inspector_edits.dart';

/// The transform rows of the selected Node (FR-029): position, size, scale,
/// angle in degrees and anchor, as many as its kind has. Plain rows —
/// built-in properties are always written in full (*Q89*), so there is no
/// Override marker, "default from code" or reset here. The 3×3 anchor
/// picker waits for the design review; the anchor is a dropdown for now.
class TransformRows extends ConsumerWidget {
  /// Creates the rows of Node [nodeId].
  const TransformRows({
    super.key,
    required this.sceneId,
    required this.nodeId,
    required this.gestures,
  });

  /// The Scene's provider key.
  final String sceneId;

  /// The edited Node.
  final NodeId nodeId;

  /// The panel's edit runs.
  final GestureKeys gestures;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final node = ref.watch(nodeProvider((sceneId, nodeId)));
    final geometry = node == null ? null : geometryOf(node);
    if (geometry == null) return const SizedBox.shrink();
    final edits = NodeEdits(ref, sceneId, nodeId, gestures);

    Widget vector(
      String label,
      Vec2 value,
      Node Function(Node, Vec2) write, {
      double step = 1,
    }) => PrVector2Property(
      label: label,
      x: value.x,
      y: value.y,
      step: step,
      onChanged: (x, y) =>
          edits.edit(label, (n) => write(n, Vec2(x ?? value.x, y ?? value.y))),
      onCommit: (x, y) => edits.edit(
        label,
        (n) => write(n, Vec2(x ?? value.x, y ?? value.y)),
        end: true,
      ),
    );

    final angle = geometry.angle;
    final radius = geometry.radius;
    return Column(
      children: [
        vector(
          'position',
          geometry.position,
          (n, v) => withGeometry(n, position: v),
        ),
        if (geometry.size case final size?)
          vector('size', size, (n, v) => withGeometry(n, size: v)),
        if (radius != null)
          PrNumberProperty(
            label: 'radius',
            value: radius,
            min: 0,
            onChanged: (v) =>
                edits.edit('radius', (n) => withGeometry(n, radius: v)),
            onCommit: (v) => edits.edit(
              'radius',
              (n) => withGeometry(n, radius: v),
              end: true,
            ),
          ),
        if (geometry.scale case final scale?)
          vector(
            'scale',
            scale,
            (n, v) => withGeometry(n, scale: v),
            step: 0.1,
          ),
        if (angle != null)
          PrNumberProperty(
            label: 'angle',
            value: angle * 180 / math.pi,
            unit: '°',
            onChanged: (v) => edits.edit(
              'angle',
              (n) => withGeometry(n, angle: v * math.pi / 180),
            ),
            onCommit: (v) => edits.edit(
              'angle',
              (n) => withGeometry(n, angle: v * math.pi / 180),
              end: true,
            ),
          ),
        PrPropertyRow(
          label: 'anchor',
          editor: PrDropdown<NodeAnchor>(
            size: PrFieldSize.dense,
            monoOptions: true,
            // A custom anchor (x, y) shows as itself and stays until one of
            // the named ones is chosen.
            options: [
              for (final anchor in [
                if (geometry.anchor.name == null) geometry.anchor,
                ...NodeAnchor.named,
              ])
                PrDropdownOption(
                  value: anchor,
                  label: anchor.name ?? '(${anchor.x}, ${anchor.y})',
                ),
            ],
            value: geometry.anchor,
            onChanged: (anchor) => edits.edit(
              'anchor',
              (n) => withGeometry(n, anchor: anchor),
              end: true,
            ),
          ),
        ),
      ],
    );
  }
}
