import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../colors.dart';
import '../floating/tooltip.dart';
import '../foundation/anchored_overlay.dart';
import '../foundation/debug_states.dart';
import '../foundation/field_box.dart';
import '../foundation/interactive.dart';
import '../foundation/value_source.dart';
import '../icons.dart';
import '../inspector/property_row.dart';
import '../metrics.dart';
import '../shadows.dart';
import '../typography.dart';

/// One choice of an [FsDropdown].
@immutable
class FsDropdownOption<T> {
  /// Creates an option.
  const FsDropdownOption({
    required this.value,
    required this.label,
    this.icon,
    this.detail,
  });

  /// What [FsDropdown.onChanged] gets.
  final T value;

  /// The short text in the field (`center`).
  final String label;

  /// A 14px icon before the label in the field, and in the list's icon
  /// column (the selected option shows its check there instead).
  final IconData? icon;

  /// The text in the list instead of [label]: an enum's Dart name
  /// (`Anchor.center`).
  final String? detail;
}

/// A select for enums and short fixed lists.
///
/// - **Field:** the [FsFieldBox] with the option's label and a trailing
///   14px chevron; hover `border-strong`, pressed `surface-hover`, focused
///   (by click too) and open get the focus border and ring; error border;
///   disabled flat. Mixed shows "—" in `text-secondary`. Inside an
///   `FsPropertyRow` it follows the row (hover, error, default values in
///   `text-secondary`).
/// - **List:** an overlay as wide as the field, below it (flipped above
///   when there's no room), opening on the current value with a check on
///   it. Items are 24px; hover and the keyboard highlight look the same
///   (`accent`, `text-on-accent`). With [monoOptions] the list shows each
///   option's [FsDropdownOption.detail] (or label) in mono.
/// - **Keyboard:** Space, Enter, ↓ and ↑ open the list; ↑ ↓ move, Enter or
///   Space choose, Esc or Tab close it without a change; typing jumps to the
///   first option that starts with the typed text (open or closed).
///
/// Focus stays on the field while the list is open. [onChanged] null
/// disables the dropdown; it is called only for a different value (or any
/// value while mixed).
///
/// For the gallery, `FsDebugStates(part: 'open', exact)` with
/// [WidgetState.selected] shows the list, and one whose part is an item's
/// list text forces that item's [WidgetState.hovered].
class FsDropdown<T> extends StatefulWidget {
  /// Creates the dropdown.
  const FsDropdown({
    super.key,
    required this.options,
    required this.value,
    this.mixed = false,
    required this.onChanged,
    this.size = FsFieldSize.regular,
    this.monoOptions = false,
    this.errorText,
    this.placeholder,
    this.focusNode,
    this.autofocus = false,
  });

  /// The choices, in list order.
  final List<FsDropdownOption<T>> options;

  /// The current value; null (or one that isn't an option) shows
  /// [placeholder].
  final T? value;

  /// The selected objects disagree: the field shows "—".
  final bool mixed;

  /// Called with the chosen value; null disables the dropdown.
  final ValueChanged<T>? onChanged;

  /// 24, or 20 inside property rows.
  final FsFieldSize size;

  /// The list shows Dart names in mono (enums).
  final bool monoOptions;

  /// An error: the `error` border, and the text (when not empty) in a
  /// tooltip.
  final String? errorText;

  /// Shown in `text-placeholder` when no option is selected.
  final String? placeholder;

  /// The field's focus node.
  final FocusNode? focusNode;

  /// Whether to take focus when first built.
  final bool autofocus;

  @override
  State<FsDropdown<T>> createState() => _FsDropdownState<T>();
}

class _FsDropdownState<T> extends State<FsDropdown<T>> {
  final _overlay = OverlayPortalController();
  final _scroll = ScrollController();
  final GlobalKey _fieldKey = GlobalKey();
  FocusNode? _ownFocusNode;
  int? _highlight;
  double _width = 0;
  String _typed = '';
  Timer? _typedTimer;
  bool _debugOpen = false;

  static const String _mixedGlyph = '—';
  static const double _itemHeight = FsSizes.control;
  static const double _listPadding = FsSpacing.s1;
  static const double _maxListHeight = 320;

  FocusNode get _focusNode =>
      widget.focusNode ??
      (_ownFocusNode ??= FocusNode(debugLabel: 'FsDropdown'));

  bool get _enabled => widget.onChanged != null;

  int? get _selectedIndex {
    if (widget.mixed) return null;
    final i = widget.options.indexWhere((o) => o.value == widget.value);
    return i < 0 ? null : i;
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(FsDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_onFocus);
      _focusNode.addListener(_onFocus);
    }
    if (!_enabled && _overlay.isShowing) _close();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocus);
    _typedTimer?.cancel();
    _scroll.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!_focusNode.hasFocus && _overlay.isShowing) _close();
    if (mounted) setState(() {});
  }

  void _open({int? highlight}) {
    if (!_enabled || _overlay.isShowing) return;
    _width = context.size?.width ?? 0;
    _focusNode.requestFocus();
    setState(() => _highlight = highlight ?? _selectedIndex);
    _overlay.show();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(center: true));
  }

  void _close() {
    if (!_overlay.isShowing) return;
    _overlay.hide();
    if (mounted) setState(() => _highlight = null);
  }

  void _toggle() => _overlay.isShowing ? _close() : _open();

  void _choose(int index) {
    final option = widget.options[index];
    _close();
    _focusNode.requestFocus();
    if (widget.mixed || option.value != widget.value) {
      widget.onChanged?.call(option.value);
    }
  }

  /// Scrolls the highlighted item into view.
  void _reveal({bool center = false}) {
    final i = _highlight;
    if (i == null || !_scroll.hasClients) return;
    final position = _scroll.position;
    final top = i * _itemHeight;
    final viewport = position.viewportDimension - 2 * _listPadding;
    double target;
    if (center) {
      target = top - (viewport - _itemHeight) / 2;
    } else if (top < position.pixels) {
      target = top;
    } else if (top + _itemHeight > position.pixels + viewport) {
      target = top + _itemHeight - viewport;
    } else {
      return;
    }
    _scroll.jumpTo(
      target.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  void _move(int by) {
    final n = widget.options.length;
    if (n == 0) return;
    final current = _highlight;
    setState(() {
      _highlight = current == null
          ? (by > 0 ? 0 : n - 1)
          : math.max(0, math.min(n - 1, current + by));
    });
    _reveal();
  }

  void _typeAhead(String character) {
    _typedTimer?.cancel();
    _typedTimer = Timer(const Duration(seconds: 1), () => _typed = '');
    _typed += character.toLowerCase();
    // One letter, or the same letter again, steps to the next option that
    // starts with it; a longer prefix searches from the current option.
    final repeat = _typed.split('').every((ch) => ch == _typed[0]);
    final prefix = repeat ? _typed[0] : _typed;
    bool matches(FsDropdownOption<T> o) => [
      o.label,
      if (o.detail != null) ...[o.detail!, o.detail!.split('.').last],
    ].any((name) => name.toLowerCase().startsWith(prefix));

    final options = widget.options;
    final current = _highlight ?? _selectedIndex ?? -1;
    final from = repeat ? current + 1 : math.max(0, current);
    int? found;
    for (var k = 0; k < options.length; k++) {
      final i = (from + k) % options.length;
      if (matches(options[i])) {
        found = i;
        break;
      }
    }
    if (found == null) return;
    if (_overlay.isShowing) {
      setState(() => _highlight = found);
      _reveal();
    } else {
      _open(highlight: found);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_enabled || (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final open = _overlay.isShowing;
    final keys = HardwareKeyboard.instance;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      if (open) {
        _move(key == LogicalKeyboardKey.arrowDown ? 1 : -1);
      } else {
        _open();
      }
      return KeyEventResult.handled;
    }
    if (open &&
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.space)) {
      final i = _highlight;
      if (i == null) {
        _close();
      } else {
        _choose(i);
      }
      return KeyEventResult.handled;
    }
    if (open && key == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    if (open && key == LogicalKeyboardKey.tab) {
      _close(); // and let Tab move focus
      return KeyEventResult.ignored;
    }
    final character = event.character;
    if (character != null &&
        character.trim().isNotEmpty &&
        !keys.isMetaPressed &&
        !keys.isControlPressed &&
        !keys.isAltPressed) {
      _typeAhead(character);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _listText(FsDropdownOption<T> o) =>
      widget.monoOptions ? (o.detail ?? o.label) : o.label;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    final row = FsPropertyRowScope.of(context);
    final debugOpen = FsDebugStates.of(
      context,
      part: 'open',
      exact: true,
    ).contains(WidgetState.selected);
    if (debugOpen && !_debugOpen && !_overlay.isShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _width = context.size?.width ?? 0;
        setState(() => _highlight = null); // items' hover comes forced too
        _overlay.show();
      });
    }
    _debugOpen = debugOpen;
    final selected = _selectedIndex;
    final option = selected == null ? null : widget.options[selected];
    final error = widget.errorText != null || (row?.error ?? false);
    final dense = widget.size == FsFieldSize.dense;

    Widget field = FsInteractive(
      key: _fieldKey,
      onPressed: _enabled ? _toggle : null,
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      requestFocusOnPress: true,
      error: error,
      semanticsLabel: widget.mixed ? _mixedGlyph : option?.label,
      builder: (context, states) {
        final disabled = states.contains(WidgetState.disabled);
        final boxStates = {
          ...states,
          if (row?.hovered ?? false) WidgetState.hovered,
          if (_focusNode.hasFocus || _overlay.isShowing || debugOpen)
            WidgetState.focused,
        };
        final Color ink;
        if (disabled) {
          ink = c.textDisabled;
        } else if (widget.mixed || row?.source == FsValueSource.codeDefault) {
          ink = c.textSecondary;
        } else if (option == null) {
          ink = c.textPlaceholder;
        } else {
          ink = c.textPrimary;
        }
        final text = widget.mixed
            ? _mixedGlyph
            : (option?.label ?? widget.placeholder ?? '');
        return FsFieldBox(
          size: widget.size,
          states: boxStates,
          padding: EdgeInsetsDirectional.only(
            start: dense ? 6 : FsSpacing.s2,
            end: FsSpacing.s1,
          ),
          trailing: const Icon(FsIcons.chevronDown, size: FsSizes.iconSm),
          child: Row(
            children: [
              if (option?.icon != null && !widget.mixed) ...[
                Icon(
                  option!.icon,
                  size: FsSizes.iconSm,
                  color: disabled ? c.textDisabled : c.textSecondary,
                ),
                const SizedBox(width: FsSpacing.s1),
              ],
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: FsText.body.copyWith(color: ink),
                ),
              ),
            ],
          ),
        );
      },
    );
    final message = widget.errorText;
    if (message != null && message.isNotEmpty) {
      field = FsTooltip(message: message, error: true, child: field);
    }
    return FsAnchoredOverlay(
      controller: _overlay,
      onDismiss: _close,
      overlayBuilder: _list,
      // Keys reach this before the app's shortcuts (Enter and Space open
      // the closed list through the field's ActivateIntent).
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onKeyEvent: _onKey,
        child: field,
      ),
    );
  }

  Widget _list(BuildContext context) {
    final c = FsColors.of(context);
    final selected = _selectedIndex;
    return Container(
      width: _width,
      constraints: const BoxConstraints(maxHeight: _maxListHeight),
      decoration: BoxDecoration(
        color: c.surfaceOverlay,
        border: Border.all(color: c.borderOverlay),
        borderRadius: FsRadii.md,
        boxShadow: FsShadows.of(context).popover,
      ),
      child: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.all(_listPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, option) in widget.options.indexed)
              MouseRegion(
                onEnter: (_) => setState(() => _highlight = i),
                child: FsInteractive(
                  onPressed: () => _choose(i),
                  focusable: false,
                  semanticsLabel: option.label,
                  selected: i == selected,
                  builder: (context, states) => _DropdownItem(
                    icon: i == selected ? FsIcons.check : option.icon,
                    text: _listText(option),
                    mono: widget.monoOptions,
                    selected: i == selected,
                    highlighted:
                        i == _highlight ||
                        FsDebugStates.of(
                          context,
                          part: _listText(option),
                          exact: true,
                        ).contains(WidgetState.hovered),
                    pressed: states.contains(WidgetState.pressed),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One 24px row of the dropdown list, drawn like a menu item.
class _DropdownItem extends StatelessWidget {
  const _DropdownItem({
    required this.icon,
    required this.text,
    required this.mono,
    required this.selected,
    required this.highlighted,
    required this.pressed,
  });

  final IconData? icon;
  final String text;
  final bool mono;
  final bool selected;
  final bool highlighted;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    final Color fill;
    final Color ink;
    final Color iconInk;
    if (pressed) {
      fill = c.accentPressed;
      ink = iconInk = c.textOnAccent;
    } else if (highlighted) {
      fill = c.accent;
      ink = iconInk = c.textOnAccent;
    } else {
      fill = Colors.transparent;
      ink = c.textPrimary;
      iconInk = selected ? c.accentText : c.textSecondary;
    }
    return Container(
      height: FsSizes.control,
      padding: const EdgeInsets.symmetric(horizontal: FsSpacing.s2),
      decoration: BoxDecoration(color: fill, borderRadius: FsRadii.sm),
      child: Row(
        children: [
          SizedBox.square(
            dimension: FsSizes.icon,
            child: icon == null
                ? null
                : Icon(icon, size: FsSizes.icon, color: iconInk),
          ),
          const SizedBox(width: FsSpacing.s2),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: (mono ? FsText.mono : FsText.body).copyWith(color: ink),
            ),
          ),
        ],
      ),
    );
  }
}
