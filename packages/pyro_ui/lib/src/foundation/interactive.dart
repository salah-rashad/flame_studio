import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'debug_states.dart';
import 'focus_ring.dart';

/// Turns pointer and keyboard input into a `Set<WidgetState>` and hands it to
/// [builder]. Every button, field box, row, tab, segment and slot is built on
/// it, so states look and behave the same everywhere.
///
/// - [WidgetState.disabled] when [onPressed] is null (unless [enabled] says
///   otherwise).
/// - [WidgetState.hovered] while a mouse is over it.
/// - [WidgetState.pressed] from a [Listener] (pointer down, up inside), not a
///   gesture recogniser, so it can sit inside drag sources without fighting
///   the gesture arena. A press that moves more than [kTouchSlop] is
///   cancelled, so a drag never ends in a click.
/// - [WidgetState.focused] only for keyboard focus: a mouse click never shows
///   the ring (see `PrInputModality`).
/// - Disabled controls are out of the Tab order, unless
///   [focusableWhenDisabled]: then they take focus and show the ring, so a
///   tooltip can say why they are disabled, but Enter and Space do nothing.
/// - [WidgetState.selected] and [WidgetState.error] from [selected] and
///   [error].
///
/// States forced by a `PrDebugStates` above it are added on top.
class PrInteractive extends StatefulWidget {
  /// Creates the wrapper.
  const PrInteractive({
    super.key,
    required this.builder,
    this.onPressed,
    this.enabled,
    this.selected = false,
    this.error = false,
    this.statesController,
    this.focusNode,
    this.autofocus = false,
    this.focusable = true,
    this.focusableWhenDisabled = false,
    this.requestFocusOnPress = false,
    this.cursor = SystemMouseCursors.basic,
    this.shortcuts,
    this.actions,
    this.semanticsLabel,
    this.semanticsToggled,
    this.semanticsChecked,
    this.semanticsMixed = false,
  });

  /// Builds the control from its current states.
  final Widget Function(BuildContext context, Set<WidgetState> states) builder;

  /// Called on click and on Enter or Space (`ActivateIntent`). Null disables
  /// the control.
  final VoidCallback? onPressed;

  /// Overrides "disabled when [onPressed] is null", for controls that react
  /// to other input (rows with double-tap or drag) but have no press action.
  final bool? enabled;

  /// Adds [WidgetState.selected].
  final bool selected;

  /// Adds [WidgetState.error].
  final bool error;

  /// For callers that need to read the states or drive extra ones (a roving
  /// focus group setting `focused` on a non-focusable child). The wrapper
  /// only updates the states it owns.
  final WidgetStatesController? statesController;

  /// The focus node; one is created when null.
  final FocusNode? focusNode;

  /// Whether to take focus when first built.
  final bool autofocus;

  /// Whether the control takes focus at all. False inside roving-focus groups
  /// (Toolbar, SegmentedControl), where the group is the Tab stop, and for
  /// rows whose list owns focus.
  final bool focusable;

  /// Whether the control keeps its Tab stop while disabled.
  ///
  /// Off by default: disabled controls are skipped, as in native toolkits,
  /// and a focused control that ignores Enter feels broken. Turn it on only
  /// for the few commands whose disabled reason lives in their tooltip
  /// ("Run game" with no device connected), so keyboard users can reach that
  /// reason. While disabled the control is still announced as disabled,
  /// [onPressed], [shortcuts] and [actions] stay inactive, and Enter and
  /// Space are swallowed. Has no effect when [focusable] is false.
  ///
  /// Prefer showing the reason where it can always be read (a banner, the
  /// empty state, the status bar); this is the fallback.
  final bool focusableWhenDisabled;

  /// Whether a pointer down moves focus here (rows); buttons leave focus
  /// where it was.
  final bool requestFocusOnPress;

  /// Cursor while enabled; disabled controls show the arrow.
  final MouseCursor cursor;

  /// Extra shortcuts, active while focused.
  final Map<ShortcutActivator, Intent>? shortcuts;

  /// Extra actions; an `ActivateIntent` action here replaces the default.
  final Map<Type, Action<Intent>>? actions;

  /// The semantics label.
  final String? semanticsLabel;

  /// Semantics toggled state (toggle buttons).
  final bool? semanticsToggled;

  /// Semantics checked state (checkboxes); null for other controls.
  final bool? semanticsChecked;

  /// Semantics mixed state (a checkbox that is neither checked nor
  /// unchecked).
  final bool semanticsMixed;

  @override
  State<PrInteractive> createState() => _FsInteractiveState();
}

class _FsInteractiveState extends State<PrInteractive> {
  WidgetStatesController? _ownController;
  FocusNode? _ownFocusNode;
  int? _pressPointer;
  Offset? _pressOrigin;

  WidgetStatesController get _controller =>
      widget.statesController ?? (_ownController ??= WidgetStatesController());

  FocusNode get _focusNode =>
      widget.focusNode ??
      (_ownFocusNode ??= FocusNode(debugLabel: 'PrInteractive'));

  bool get _enabled => widget.enabled ?? widget.onPressed != null;

  bool get _takesFocus =>
      widget.focusable && (_enabled || widget.focusableWhenDisabled);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_rebuild);
    _focusNode.addListener(_syncFocus);
    PrInputModality.instance.addListener(_syncFocus);
    _syncStatic();
  }

  @override
  void didUpdateWidget(PrInteractive oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.statesController != widget.statesController) {
      (oldWidget.statesController ?? _ownController)?.removeListener(_rebuild);
      _controller.addListener(_rebuild);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_syncFocus);
      _focusNode.addListener(_syncFocus);
    }
    _syncStatic();
    _syncFocus();
  }

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    _focusNode.removeListener(_syncFocus);
    PrInputModality.instance.removeListener(_syncFocus);
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _syncStatic() {
    final c = _controller;
    c.update(WidgetState.disabled, !_enabled);
    c.update(WidgetState.selected, widget.selected);
    c.update(WidgetState.error, widget.error);
    if (!_enabled) {
      c.update(WidgetState.pressed, false);
      _pressPointer = null;
    }
  }

  void _syncFocus() {
    if (!widget.focusable) return;
    _controller.update(
      WidgetState.focused,
      _takesFocus &&
          _focusNode.hasFocus &&
          PrInputModality.instance.showsFocusRing,
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!_enabled || event.buttons != kPrimaryButton) return;
    _pressPointer = event.pointer;
    _pressOrigin = event.position;
    _controller.update(WidgetState.pressed, true);
    if (widget.requestFocusOnPress && widget.focusable) {
      _focusNode.requestFocus();
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _pressPointer) return;
    if ((event.position - _pressOrigin!).distance > kTouchSlop) _cancelPress();
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _pressPointer) return;
    _cancelPress();
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    if ((Offset.zero & box.size).contains(box.globalToLocal(event.position))) {
      widget.onPressed?.call();
    }
  }

  void _cancelPress() {
    _pressPointer = null;
    _controller.update(WidgetState.pressed, false);
  }

  @override
  Widget build(BuildContext context) {
    final states = {..._controller.value, ...PrDebugStates.of(context)};
    final onPressed = _enabled ? widget.onPressed : null;
    Widget child = Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: (_) => _cancelPress(),
      child: MouseRegion(
        cursor: _enabled ? widget.cursor : SystemMouseCursors.basic,
        onEnter: (_) => _controller.update(WidgetState.hovered, true),
        onExit: (_) => _controller.update(WidgetState.hovered, false),
        child: widget.builder(context, states),
      ),
    );
    child = Actions(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onPressed?.call();
            return null;
          },
        ),
        if (_enabled) ...?widget.actions,
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        canRequestFocus: _takesFocus,
        skipTraversal: !widget.focusable,
        includeSemantics: false,
        child: child,
      ),
    );
    if (widget.shortcuts != null) {
      // Kept (empty) while disabled, so the tree and focus survive toggling.
      child = Shortcuts(
        shortcuts: _enabled ? widget.shortcuts! : const {},
        child: child,
      );
    }
    return Semantics(
      container: true,
      button: widget.onPressed != null || widget.semanticsToggled != null,
      enabled: _enabled,
      selected: widget.selected,
      toggled: widget.semanticsToggled,
      checked: widget.semanticsChecked,
      mixed: widget.semanticsMixed ? true : null,
      focusable: _takesFocus,
      focused: widget.focusable && _focusNode.hasFocus,
      label: widget.semanticsLabel,
      onTap: onPressed,
      child: child,
    );
  }
}

/// Picks a colour for a set of states.
///
/// ```dart
/// PrStateColor.resolve(states, {
///   WidgetState.disabled: c.textDisabled,
///   WidgetState.pressed: c.surfacePressed,
///   WidgetState.hovered: c.surfaceHover,
/// }, fallback: c.surfacePanel)
/// ```
///
/// The first entry whose state is in [states] wins, so list them in priority
/// order (map literals keep their order).
abstract final class PrStateColor {
  /// The colour of the first matching state, or [fallback].
  static Color resolve(
    Set<WidgetState> states,
    Map<WidgetState, Color> colors, {
    required Color fallback,
  }) {
    for (final MapEntry(:key, :value) in colors.entries) {
      if (states.contains(key)) return value;
    }
    return fallback;
  }
}
