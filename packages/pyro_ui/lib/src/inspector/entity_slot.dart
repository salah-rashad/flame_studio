import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../icons.dart';
import 'slot.dart';

/// A reference to another node or component in the scene: its type icon
/// and name, a crosshair to pick it in the scene, clear, and a drop target.
/// The editor of a component-reference field's `PrPropertyRow`.
///
/// - 20px; the 14px [typeIcon] (a link icon while empty), the [name] in the
///   UI font, the crosshair and, when filled, clear (×).
/// - Empty: [placeholder] ("None (CameraComponent)") in
///   `text-placeholder`.
/// - **Picking** ([picking]): the crosshair latched (`accent-subtle`,
///   `accent-text`), the `accent-text` edge and [pickingHint] ("Click a node
///   in the scene…"). The app highlights valid targets; the crosshair again
///   or Esc calls [onCancelPick].
/// - **Drop target**, wrong type, missing (the old name in `error` and the
///   [missingLabel] badge), mixed and disabled: as `PrAssetSlot`.
/// - A click on the name selects and frames the node ([onReveal]); a click
///   on the placeholder or Enter starts picking; ⌫ clears while focused.
///
/// `D` is the drag payload type the app uses (a tree row's data). Part for
/// `PrDebugStates`: `drop` (see `PrSlot`).
class PrEntitySlot<D extends Object> extends StatelessWidget {
  /// Creates the slot.
  const PrEntitySlot({
    super.key,
    required this.name,
    required this.placeholder,
    this.typeIcon,
    this.missing = false,
    this.missingLabel,
    this.mixed = false,
    this.mixedLabel,
    this.picking = false,
    this.pickingHint,
    this.onPick,
    this.onCancelPick,
    this.pickTooltip,
    this.onClear,
    this.clearTooltip,
    this.onReveal,
    this.willAccept,
    this.onDrop,
    this.dropHint,
    this.dragInFlight,
    this.enabled = true,
    this.focusNode,
  });

  /// The referenced node's name; null for empty.
  final String? name;

  /// Shown while empty: "None (CameraComponent)".
  final String placeholder;

  /// The referenced node's type icon; the link icon when null or empty.
  final IconData? typeIcon;

  /// The node was deleted or left the scene; [name] stays visible.
  final bool missing;

  /// The badge while [missing] ("Missing").
  final String? missingLabel;

  /// The selected objects disagree.
  final bool mixed;

  /// Shown while [mixed] ("— (3 different)").
  final String? mixedLabel;

  /// Pick mode is on: the crosshair is latched.
  final bool picking;

  /// Shown while [picking] ("Click a node in the scene…").
  final String? pickingHint;

  /// Starts pick mode: the crosshair, Enter, or a click on the placeholder.
  final VoidCallback? onPick;

  /// Ends pick mode without a choice: the crosshair again, or Esc.
  final VoidCallback? onCancelPick;

  /// The crosshair's tooltip ("Pick in scene").
  final String? pickTooltip;

  /// Clears the reference: the × button and ⌫.
  final VoidCallback? onClear;

  /// The × button's tooltip.
  final String? clearTooltip;

  /// A click on the name: select and frame the node.
  final VoidCallback? onReveal;

  /// Whether a dragged payload fits.
  final PrDropAcceptance Function(D data)? willAccept;

  /// A fitting payload was dropped.
  final ValueChanged<D>? onDrop;

  /// The drop target's text ("Drop Player here").
  final String Function(D data)? dropHint;

  /// The app's drag in progress, so every fitting slot lights up.
  final ValueListenable<D?>? dragInFlight;

  /// False disables the slot.
  final bool enabled;

  /// The focus node.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final filled = name != null && !mixed;
    return PrSlot<D>(
      icon: filled ? (typeIcon ?? PrIcons.link) : PrIcons.link,
      iconBackground: false,
      name: name,
      placeholder: placeholder,
      mono: false,
      missing: missing,
      missingLabel: missingLabel,
      mixed: mixed,
      mixedLabel: mixedLabel,
      picking: picking,
      pickingHint: pickingHint,
      actions: [
        PrSlotAction(
          icon: PrIcons.crosshair,
          tooltip: pickTooltip ?? '',
          latched: picking,
          onPressed: picking ? onCancelPick : onPick,
        ),
      ],
      onClear: onClear,
      clearTooltip: clearTooltip,
      onActivate: picking ? onCancelPick : onPick,
      onEscape: onCancelPick,
      onNameTap: filled && !picking ? onReveal : onPick,
      willAccept: willAccept,
      onDrop: onDrop,
      dropHint: dropHint,
      dragInFlight: dragInFlight,
      enabled: enabled,
      focusNode: focusNode,
      semanticsLabel: mixed ? mixedLabel : (name ?? placeholder),
    );
  }
}
