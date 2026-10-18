import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';

/// A page: a title, an optional note and its sections, scrolling.
class GalleryPage extends StatelessWidget {
  const GalleryPage({
    super.key,
    required this.title,
    this.note,
    required this.children,
  });

  final String title;
  final String? note;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(FsSpacing.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: FsText.title.copyWith(color: c.textPrimary)),
          if (note != null) ...[
            const SizedBox(height: FsSpacing.s2),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Text(
                note!,
                style: FsText.small.copyWith(color: c.textSecondary),
              ),
            ),
          ],
          for (final child in children) ...[
            const SizedBox(height: FsSpacing.s6),
            child,
          ],
        ],
      ),
    );
  }
}

/// A section heading in the preview.html style (`ds-h`).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: FsSpacing.s2),
    child: Text(
      text,
      style: FsText.caption.copyWith(color: FsColors.of(context).textSecondary),
    ),
  );
}

/// A panel-coloured box the samples sit on (`ds-box`).
class SampleBox extends StatelessWidget {
  const SampleBox({super.key, required this.child, this.width});

  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: c.surfacePanel,
        border: Border.all(color: c.borderSubtle),
        borderRadius: FsRadii.sm,
      ),
      child: child,
    );
  }
}

/// One row of a [StateGrid]: its label and one sample per column.
class GridRow {
  const GridRow(this.label, this.cells);

  final String label;
  final List<Widget> cells;
}

/// The preview.html state grid: row labels on the left, column headings on
/// top, one sample per cell.
class StateGrid extends StatelessWidget {
  const StateGrid({
    super.key,
    required this.columns,
    required this.rows,
    this.cellWidth = 320,
    this.labelWidth = 140,
  });

  final List<String> columns;
  final List<GridRow> rows;
  final double cellWidth;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    final label = FsText.small.copyWith(color: c.textSecondary);
    // Wide grids scroll sideways instead of overflowing at 1280×800.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(width: labelWidth),
              for (final column in columns)
                SizedBox(
                  width: cellWidth + FsSpacing.s4,
                  child: SectionLabel(column),
                ),
            ],
          ),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: FsSpacing.s2),
              child: Row(
                children: [
                  SizedBox(
                    width: labelWidth,
                    child: Text(row.label, style: label),
                  ),
                  for (final cell in row.cells)
                    Padding(
                      padding: const EdgeInsets.only(right: FsSpacing.s4),
                      child: SampleBox(width: cellWidth, child: cell),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Wraps [child] in forced states, optionally for one part.
Widget forced(Set<WidgetState> states, Widget child, {String? part}) =>
    FsDebugStates(states: states, part: part, child: child);

void noop([Object? _, Object? _]) {}
