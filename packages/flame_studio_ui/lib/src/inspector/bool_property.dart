import 'package:flutter/widgets.dart';

import '../foundation/value_source.dart';
import '../inputs/checkbox.dart';
import 'property_row.dart';

/// Which control an [FsBoolProperty] draws.
enum FsBoolStyle {
  /// A 14px [FsCheckbox]: fields saved with the scene (the default).
  checkbox,

  /// An [FsSwitch] (named `toggle`: `switch` is a Dart keyword), only for
  /// live toggles that take effect at once and aren't saved ("Pause on
  /// error").
  toggle,
}

/// A `bool` inspector row: the field's name and a checkbox (or a switch).
///
/// - Clicking the label toggles, as does Space on the focused control.
/// - Mixed ([value] null or [mixed]): the checkbox shows a dash and a click
///   sets every selected object to `true`. The switch has no mixed look
///   (the design leaves it out) and draws off.
/// - Default from code, overridden (bar, reset), disabled: as
///   [FsPropertyRow].
///
/// [onChanged] null disables the row.
class FsBoolProperty extends StatelessWidget {
  /// Creates the row.
  const FsBoolProperty({
    super.key,
    required this.label,
    required this.value,
    this.mixed = false,
    this.source = FsValueSource.codeDefault,
    this.onReset,
    this.resetTooltip,
    this.tooltip,
    required this.onChanged,
    this.style = FsBoolStyle.checkbox,
    this.focusNode,
  });

  /// The field's Dart name.
  final String label;

  /// The value; null when mixed.
  final bool? value;

  /// The selected objects disagree.
  final bool mixed;

  /// Default from code or overridden.
  final FsValueSource source;

  /// Restores the default; shown when overridden.
  final VoidCallback? onReset;

  /// The reset button's tooltip.
  final String? resetTooltip;

  /// The label's tooltip (type and default value).
  final String? tooltip;

  /// Called with the new value; null disables the row.
  final ValueChanged<bool>? onChanged;

  /// Checkbox or switch.
  final FsBoolStyle style;

  /// The control's focus node.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    final current = mixed ? null : value;
    final Widget control = switch (style) {
      FsBoolStyle.checkbox => FsCheckbox(
        value: current,
        onChanged: onChanged,
        semanticsLabel: label,
        focusNode: focusNode,
      ),
      FsBoolStyle.toggle => FsSwitch(
        value: current ?? false,
        onChanged: onChanged,
        semanticsLabel: label,
        focusNode: focusNode,
      ),
    };
    return FsPropertyRow(
      label: label,
      source: source,
      onReset: onReset,
      resetTooltip: resetTooltip,
      tooltip: tooltip,
      mixed: current == null,
      enabled: onChanged != null,
      // Always set (the row ignores it while disabled), so enabling the
      // row never changes the label's subtree.
      onLabelPressed: () => onChanged?.call(!(current ?? false)),
      editor: Align(
        alignment: AlignmentDirectional.centerStart,
        child: control,
      ),
    );
  }
}
