import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../colors.dart';
import '../floating/tooltip.dart';
import '../foundation/debug_states.dart';
import '../foundation/focus_ring.dart';
import '../foundation/interactive.dart';
import '../icons.dart';
import '../metrics.dart';
import '../status/badge.dart';
import '../typography.dart';

/// What a slot does with a dragged payload, decided by the app's
/// `willAccept`.
enum PrDropAcceptance {
  /// The payload fits: the slot shows the drop-target state and takes it.
  accept,

  /// The payload is the wrong type: under the pointer the slot shows the
  /// `error` edge and the not-allowed cursor.
  reject,

  /// Not a payload this slot cares about: no reaction at all.
  ignore,
}

/// The payload of the drag in progress anywhere in the app, or null.
///
/// Flutter's `DragTarget` only hears about a drag under the pointer, so
/// slots can't light up on their own while a drag starts elsewhere. The app
/// sets [value] when a drag starts (an asset from the Assets panel, a node
/// from the tree) and clears it when the drag ends; every slot given this
/// notifier then shows the quiet accept state when the payload fits.
class PrDragInFlight<D> extends ValueNotifier<D?> {
  /// No drag in progress.
  PrDragInFlight() : super(null);
}

/// A button inside a slot (browse, pick): 16px, a 12px glyph,
/// `text-secondary`; hover `surface-pressed` and `text-primary`; latched
/// `accent-subtle` and `accent-text`.
///
/// Internal.
@immutable
class PrSlotAction {
  /// Creates an action.
  const PrSlotAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.latched = false,
  });

  /// The glyph.
  final IconData icon;

  /// Tooltip and semantics label.
  final String tooltip;

  /// Null disables the action.
  final VoidCallback? onPressed;

  /// Drawn on (the entity slot's crosshair while picking).
  final bool latched;
}

/// The 20px reference slot shared by `PrAssetSlot` and `PrEntitySlot`: a
/// 16px thumbnail or icon, the name (or a placeholder), actions, and a drop
/// target.
///
/// - Default `surface-input` with a `border-control` edge; hover
///   `border-strong`; keyboard focus the `focus-ring` edge and outer ring.
/// - **Drop target** (a fitting payload under the pointer, or in flight via
///   [dragInFlight]): `accent-subtle` fill, `accent-text` edge and outer
///   ring, the [dropHint] in `accent-text` instead of the name.
/// - **Wrong type** under the pointer: `error` edge, not-allowed cursor.
/// - **Missing:** `error-subtle` fill, `error-border` edge, an alert icon on
///   `error-subtle`, the old name in `error`, and the [missingLabel] badge.
/// - **Picking:** `accent-text` edge, [pickingHint] in `accent-text`.
/// - **Mixed:** [mixedLabel] in `text-secondary`. **Disabled:** flat
///   `surface-panel`, `border-subtle`, everything `text-disabled`.
/// - Keyboard: Enter/Space [onActivate]; ⌫ or Delete [onClear]; Esc
///   [onEscape] while [picking].
///
/// Internal. Parts for `PrDebugStates`: `action` (exact) for the 16px
/// buttons, and `drop` (exact):
/// [WidgetState.selected] draws the drop target, [WidgetState.error] the
/// wrong type.
class PrSlot<D extends Object> extends StatefulWidget {
  /// Creates a slot.
  const PrSlot({
    super.key,
    required this.icon,
    this.thumbnail,
    this.iconBackground = true,
    required this.name,
    required this.placeholder,
    this.mono = true,
    this.missing = false,
    this.missingLabel,
    this.mixed = false,
    this.mixedLabel,
    this.picking = false,
    this.pickingHint,
    this.actions = const [],
    this.onClear,
    this.clearTooltip,
    this.onActivate,
    this.onEscape,
    this.onNameTap,
    this.onNameDoubleTap,
    this.willAccept,
    this.onDrop,
    this.dropHint,
    this.dragInFlight,
    this.enabled = true,
    this.focusNode,
    this.semanticsLabel,
  });

  /// The icon in the 16px thumbnail box (a type icon).
  final IconData icon;

  /// An image for the box instead of [icon] while a name is shown.
  final Widget? thumbnail;

  /// Draw the box on `surface-pressed` (asset slots); entity slots draw the
  /// icon alone.
  final bool iconBackground;

  /// What the slot refers to; null for empty.
  final String? name;

  /// Shown while empty ("None (Sprite)").
  final String placeholder;

  /// The name in mono (file names) or in the UI font (node names).
  final bool mono;

  /// The reference is broken; the old [name] stays.
  final bool missing;

  /// The badge text while [missing] ("Missing").
  final String? missingLabel;

  /// The selected objects disagree.
  final bool mixed;

  /// Shown while [mixed] ("— (2 different)").
  final String? mixedLabel;

  /// Pick mode is on (entity slots).
  final bool picking;

  /// Shown while [picking] ("Click a node in the scene…").
  final String? pickingHint;

  /// Buttons before the clear button.
  final List<PrSlotAction> actions;

  /// Clears the reference: the × button (shown when filled) and ⌫.
  final VoidCallback? onClear;

  /// The × button's tooltip.
  final String? clearTooltip;

  /// Enter or Space while focused.
  final VoidCallback? onActivate;

  /// Esc while focused and [picking].
  final VoidCallback? onEscape;

  /// A click on the name or placeholder.
  final VoidCallback? onNameTap;

  /// A double click on the name.
  final VoidCallback? onNameDoubleTap;

  /// Whether a dragged payload fits; null takes nothing.
  final PrDropAcceptance Function(D data)? willAccept;

  /// A fitting payload was dropped.
  final ValueChanged<D>? onDrop;

  /// The drop target's text for a payload ("Drop coin.png here").
  final String Function(D data)? dropHint;

  /// The app's drag in progress, for the quiet accept state.
  final ValueListenable<D?>? dragInFlight;

  /// False disables the slot.
  final bool enabled;

  /// The focus node.
  final FocusNode? focusNode;

  /// The semantics label.
  final String? semanticsLabel;

  @override
  State<PrSlot<D>> createState() => _FsSlotState<D>();
}

class _FsSlotState<D extends Object> extends State<PrSlot<D>> {
  D? _over;
  PrDropAcceptance? _overAcceptance;

  @override
  void initState() {
    super.initState();
    widget.dragInFlight?.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(PrSlot<D> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dragInFlight != widget.dragInFlight) {
      oldWidget.dragInFlight?.removeListener(_rebuild);
      widget.dragInFlight?.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.dragInFlight?.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  PrDropAcceptance _acceptance(D data) =>
      widget.enabled && widget.willAccept != null && widget.onDrop != null
      ? widget.willAccept!(data)
      : PrDropAcceptance.ignore;

  bool _willAccept(DragTargetDetails<D> details) {
    final acceptance = _acceptance(details.data);
    setState(() {
      _over = details.data;
      _overAcceptance = acceptance;
    });
    return acceptance == PrDropAcceptance.accept;
  }

  void _leave(D? _) {
    if (_over == null) return;
    setState(() {
      _over = null;
      _overAcceptance = null;
    });
  }

  void _accept(DragTargetDetails<D> details) {
    _leave(null);
    widget.onDrop?.call(details.data);
  }

  @override
  Widget build(BuildContext context) {
    final forcedDrop = PrDebugStates.of(context, part: 'drop', exact: true);
    final inFlight = widget.dragInFlight?.value;
    final D? accepting;
    if (_overAcceptance == PrDropAcceptance.accept) {
      accepting = _over;
    } else if (_over == null &&
        inFlight != null &&
        _acceptance(inFlight) == PrDropAcceptance.accept) {
      accepting = inFlight;
    } else {
      accepting = null;
    }
    final dropping =
        widget.enabled &&
        (accepting != null || forcedDrop.contains(WidgetState.selected));
    final rejecting =
        widget.enabled &&
        !dropping &&
        (_overAcceptance == PrDropAcceptance.reject ||
            forcedDrop.contains(WidgetState.error));
    final hint = accepting == null ? null : widget.dropHint?.call(accepting);

    final slot = PrInteractive(
      enabled: widget.enabled,
      focusNode: widget.focusNode,
      requestFocusOnPress: true,
      cursor: rejecting
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.basic,
      semanticsLabel: widget.semanticsLabel,
      // Always a map, so the subtree keeps its shape.
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.backspace):
            const _ClearIntent(),
        const SingleActivator(LogicalKeyboardKey.delete): const _ClearIntent(),
        if (widget.picking && widget.onEscape != null)
          const SingleActivator(LogicalKeyboardKey.escape):
              const _EscapeIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onActivate?.call();
            return null;
          },
        ),
        _ClearIntent: CallbackAction<_ClearIntent>(
          onInvoke: (_) {
            if (widget.name != null && !widget.mixed) widget.onClear?.call();
            return null;
          },
        ),
        _EscapeIntent: CallbackAction<_EscapeIntent>(
          onInvoke: (_) {
            widget.onEscape?.call();
            return null;
          },
        ),
      },
      builder: (context, states) => _SlotBox(
        slot: widget,
        states: states,
        dropping: dropping,
        rejecting: rejecting,
        hint: hint,
      ),
    );
    return DragTarget<D>(
      onWillAcceptWithDetails: _willAccept,
      onLeave: _leave,
      onAcceptWithDetails: _accept,
      builder: (context, candidates, rejected) => slot,
    );
  }
}

class _ClearIntent extends Intent {
  const _ClearIntent();
}

class _EscapeIntent extends Intent {
  const _EscapeIntent();
}

/// The drawn slot for one set of states.
class _SlotBox extends StatelessWidget {
  const _SlotBox({
    required this.slot,
    required this.states,
    required this.dropping,
    required this.rejecting,
    required this.hint,
  });

  final PrSlot<Object> slot;
  final Set<WidgetState> states;
  final bool dropping;
  final bool rejecting;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    final disabled = states.contains(WidgetState.disabled);
    final focused = states.contains(WidgetState.focused);
    final hovered = states.contains(WidgetState.hovered);
    final missing = slot.missing && !slot.mixed;
    final filled = slot.name != null && !slot.mixed;

    var fill = c.surfaceInput;
    var edge = c.borderControl;
    Color? ring;
    if (disabled) {
      fill = c.surfacePanel;
      edge = c.borderSubtle;
    } else if (dropping) {
      fill = c.accentSubtle;
      edge = ring = c.accentText;
    } else {
      if (missing) {
        fill = c.errorSubtle;
        edge = c.errorBorder;
      }
      if (rejecting) {
        edge = c.error;
      } else if (slot.picking) {
        edge = c.accentText;
      } else if (focused) {
        edge = ring = c.focusRing;
      } else if (hovered && !missing) {
        edge = c.borderStrong;
      }
    }

    // The text: a drop hint, the pick hint, mixed, the name or the
    // placeholder.
    final String text;
    final Color ink;
    var isName = false;
    if (dropping && hint != null) {
      text = hint!;
      ink = c.accentText;
    } else if (slot.picking && !disabled) {
      text = slot.pickingHint ?? slot.placeholder;
      ink = c.accentText;
    } else if (slot.mixed) {
      text = slot.mixedLabel ?? '—';
      ink = disabled ? c.textDisabled : c.textSecondary;
    } else if (filled) {
      text = slot.name!;
      isName = true;
      if (disabled) {
        ink = c.textDisabled;
      } else {
        ink = missing ? c.error : c.textPrimary;
      }
    } else {
      text = slot.placeholder;
      ink = disabled
          ? c.textDisabled
          : (dropping ? c.accentText : c.textPlaceholder);
    }
    final showsName = isName && !dropping && !slot.picking;
    final style = (showsName && slot.mono ? PrText.mono : PrText.body).copyWith(
      color: ink,
    );

    // The thumbnail box: the image while a name shows, the alert icon while
    // missing, the type icon otherwise.
    final thumbnail = slot.thumbnail;
    final Widget thumb;
    if (missing && showsName) {
      thumb = _ThumbBox(
        background: c.errorSubtle,
        child: Icon(
          PrIcons.alertCircle,
          size: 12,
          color: disabled ? c.textDisabled : c.error,
        ),
      );
    } else if (showsName && thumbnail != null) {
      thumb = _ThumbBox(
        background: c.surfacePressed,
        child: SizedBox.expand(child: thumbnail),
      );
    } else {
      final quiet = disabled ? c.textDisabled : c.textSecondary;
      thumb = _ThumbBox(
        background: slot.iconBackground ? c.surfacePressed : null,
        child: Icon(
          slot.icon,
          size: slot.iconBackground ? 12 : PrSizes.iconSm,
          color: dropping || slot.picking ? c.accentText : quiet,
        ),
      );
    }

    final actionsEnabled = !disabled;
    final missingLabel = slot.missingLabel;
    return CustomPaint(
      foregroundPainter: ring == null
          ? null
          : PrEdgePainter(
              color: ring,
              width: 1,
              borderRadius: PrRadii.sm,
              outside: true,
            ),
      child: Container(
        height: PrSizes.controlSm,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: edge),
          borderRadius: PrRadii.sm,
        ),
        child: Row(
          children: [
            thumb,
            const SizedBox(width: PrSpacing.s1),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: actionsEnabled ? slot.onNameTap : null,
                onDoubleTap: actionsEnabled && showsName
                    ? slot.onNameDoubleTap
                    : null,
                child: Text(
                  text,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ),
            if (missing && showsName && missingLabel != null) ...[
              const SizedBox(width: PrSpacing.s1),
              // No icon: the slot's thumbnail already shows the alert
              // circle (preview.html draws the word alone).
              PrBadge(
                kind: PrBadgeKind.missing,
                label: missingLabel,
                showIcon: false,
              ),
            ],
            for (final action in slot.actions) ...[
              const SizedBox(width: PrSpacing.s1),
              _ActionButton(action: action, enabled: actionsEnabled),
            ],
            if (filled &&
                !dropping &&
                !slot.picking &&
                slot.onClear != null) ...[
              const SizedBox(width: PrSpacing.s1),
              _ActionButton(
                action: PrSlotAction(
                  icon: PrIcons.x,
                  tooltip: slot.clearTooltip ?? '',
                  onPressed: slot.onClear,
                ),
                enabled: actionsEnabled,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The 16px thumbnail box.
class _ThumbBox extends StatelessWidget {
  const _ThumbBox({required this.child, this.background});

  final Widget child;
  final Color? background;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: PrRadii.xs,
    child: Container(
      width: PrSizes.icon,
      height: PrSizes.icon,
      alignment: Alignment.center,
      color: background,
      child: child,
    ),
  );
}

/// A 16px button inside a slot.
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, required this.enabled});

  final PrSlotAction action;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    // Shielded: states forced on the whole slot (the gallery's Hover row)
    // don't light its buttons; part `action` (exact) forces them.
    final Widget button = PrDebugStates(
      states: PrDebugStates.of(context, part: 'action', exact: true),
      child: PrInteractive(
        onPressed: enabled ? action.onPressed : null,
        focusable: false,
        semanticsLabel: action.tooltip,
        selected: action.latched,
        builder: (context, states) {
          final disabled = states.contains(WidgetState.disabled);
          final hot =
              states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.pressed);
          final Color fill;
          final Color ink;
          if (disabled) {
            fill = Colors.transparent;
            ink = c.textDisabled;
          } else if (action.latched) {
            fill = c.accentSubtle;
            ink = c.accentText;
          } else if (hot) {
            fill = c.surfacePressed;
            ink = c.textPrimary;
          } else {
            fill = Colors.transparent;
            ink = c.textSecondary;
          }
          return Container(
            width: PrSizes.icon,
            height: PrSizes.icon,
            decoration: BoxDecoration(color: fill, borderRadius: PrRadii.xs),
            child: Icon(action.icon, size: 12, color: ink),
          );
        },
      ),
    );
    return action.tooltip.isEmpty
        ? button
        : PrTooltip(message: action.tooltip, child: button);
  }
}
