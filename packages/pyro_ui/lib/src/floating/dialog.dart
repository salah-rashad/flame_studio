import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../actions/button.dart';
import '../actions/icon_button.dart';
import '../colors.dart';
import '../foundation/debug_states.dart';
import '../icons.dart';
import '../metrics.dart';
import '../shadows.dart';
import '../typography.dart';

/// A [PrDialog] button: its label and the value the dialog returns when it
/// is pressed.
@immutable
class PrDialogAction<T> {
  /// Creates the action.
  const PrDialogAction({required this.label, this.value});

  /// A verb that answers the title: "Save", "Don't save", "Cancel".
  final String label;

  /// What `showFsDialog` returns for this button.
  final T? value;
}

/// The two dialog widths.
enum PrDialogWidth {
  /// 440: questions and confirmations.
  regular,

  /// 560: short forms (new scene, export).
  form,
}

/// A modal decision: unsaved changes, a destructive confirmation, a short
/// form. Show it with [showFsDialog].
///
/// `surface-overlay`, 1px `border-overlay`, `radius-lg`, `shadow-dialog`,
/// over the `scrim`. Header: [title] in `title` and the close ×. Body:
/// [body] in `text-secondary`, then [content] (fields, a checkbox; text
/// in it defaults to `text-primary`). Footer, under a 1px `border-overlay`
/// edge: [destructive] on the left, apart; [secondary] and [primary] on the
/// right.
///
/// Keys: [primary] has initial focus and answers Enter (unless another
/// button has focus; also from a single-line text field in [content]); Esc
/// and the close × answer [secondary] (null without one). A field in
/// [content] with `autofocus` takes initial focus instead of [primary].
/// Tab cycles inside the dialog; on close, focus goes back to where it was
/// (the route's default).
///
/// Parts for `PrDebugStates` (all exact): `primary`, `secondary`,
/// `destructive` and `close`, the states of each button.
class PrDialog<T> extends StatelessWidget {
  /// Creates the dialog.
  const PrDialog({
    super.key,
    required this.title,
    this.body,
    this.content,
    required this.primary,
    this.secondary,
    this.destructive,
    this.width = PrDialogWidth.regular,
    this.closeTooltip,
  });

  /// A question or an action: "Save changes to level_1.scene?".
  final String title;

  /// The explanation, in `text-secondary`.
  final String? body;

  /// Fields or a checkbox under the [body].
  final Widget? content;

  /// The answer the dialog is for; initial focus, answers Enter.
  final PrDialogAction<T> primary;

  /// "Cancel"; also Esc and the close ×.
  final PrDialogAction<T>? secondary;

  /// The destructive answer ("Don't save"), on the left, apart.
  final PrDialogAction<T>? destructive;

  /// 440, or 560 for forms.
  final PrDialogWidth width;

  /// The close ×'s tooltip and semantics label ("Close").
  final String? closeTooltip;

  void _answer(BuildContext context, PrDialogAction<T>? action) {
    // maybePop: a dialog drawn inline (the gallery) sits on the first
    // route, which this leaves alone.
    unawaited(Navigator.of(context).maybePop<T>(action?.value));
  }

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    Widget part(String name, Widget child) => PrDebugStates(
      states: PrDebugStates.of(context, part: name, exact: true),
      child: child,
    );

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        PrSpacing.s4,
        PrSpacing.s4,
        PrSpacing.s3,
        0,
      ),
      child: Row(
        spacing: PrSpacing.s2,
        children: [
          Expanded(
            child: Text(
              title,
              style: PrText.title.copyWith(color: c.textPrimary),
            ),
          ),
          part(
            'close',
            PrIconButton(
              icon: PrIcons.x,
              iconSize: PrSizes.iconSm,
              size: PrIconButtonSize.small,
              tooltip: closeTooltip ?? '',
              onPressed: () => _answer(context, secondary),
            ),
          ),
        ],
      ),
    );

    final hasBody = body != null || content != null;
    final bodyPart = Padding(
      padding: const EdgeInsets.fromLTRB(
        PrSpacing.s4,
        PrSpacing.s2,
        PrSpacing.s4,
        PrSpacing.s4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: PrSpacing.s3,
        children: [
          if (body != null)
            Text(body!, style: PrText.body.copyWith(color: c.textSecondary)),
          if (content != null)
            DefaultTextStyle(
              style: PrText.body.copyWith(color: c.textPrimary),
              child: content!,
            ),
        ],
      ),
    );

    final footer = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PrSpacing.s4,
        vertical: PrSpacing.s3,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.borderOverlay)),
      ),
      child: Row(
        spacing: PrSpacing.s2,
        children: [
          if (destructive case final action?)
            part(
              'destructive',
              PrButton(
                label: action.label,
                variant: PrButtonVariant.danger,
                onPressed: () => _answer(context, action),
              ),
            ),
          const Spacer(),
          if (secondary case final action?)
            part(
              'secondary',
              PrButton(
                label: action.label,
                onPressed: () => _answer(context, action),
              ),
            ),
          part(
            'primary',
            _InitialFocus(
              builder: (node) => PrButton(
                label: primary.label,
                variant: PrButtonVariant.primary,
                focusNode: node,
                onPressed: () => _answer(context, primary),
              ),
            ),
          ),
        ],
      ),
    );

    // A route from showGeneralDialog has no Material, so text below would
    // fall back to the debug style (double yellow underlines): the
    // transparent Material gives it the theme's body style.
    return Material(
      type: MaterialType.transparency,
      textStyle: PrText.body.copyWith(color: c.textPrimary),
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: title,
        // Enter and Esc arrive as the app's ActivateIntent and DismissIntent;
        // a focused button or an open menu inside answers them first.
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: (node, event) => _onKey(context, event),
          child: Actions(
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) => _answer(context, primary),
              ),
              DismissIntent: CallbackAction<DismissIntent>(
                onInvoke: (_) => _answer(context, secondary),
              ),
            },
            // Tab wraps inside the dialog instead of leaving the route.
            child: _TrapFocus(
              child: Container(
                width: switch (width) {
                  PrDialogWidth.regular => 440,
                  PrDialogWidth.form => 560,
                },
                decoration: BoxDecoration(
                  color: c.surfaceOverlay,
                  border: Border.all(color: c.borderOverlay),
                  borderRadius: PrRadii.lg,
                  boxShadow: PrShadows.of(context).dialog,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    if (hasBody)
                      bodyPart
                    else
                      const SizedBox(height: PrSpacing.s4),
                    footer,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A text field keeps Enter from the app's shortcuts (it submits the
  /// field), so a form answers [primary] here; other keys pass on.
  KeyEventResult _onKey(BuildContext context, KeyEvent event) {
    final enter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (!enter || event is KeyUpEvent) return KeyEventResult.ignored;
    final field = FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<EditableText>();
    if (field == null || field.maxLines != 1) return KeyEventResult.ignored;
    if (event is KeyDownEvent) _answer(context, primary);
    return KeyEventResult.handled;
  }
}

/// Shows [dialog] over the `scrim` with a 200ms fade (no scale) and
/// returns the value of the button that closed it (null for Esc or the
/// close × without a secondary action).
///
/// With [barrierDismissible], a click on the scrim answers like Esc (the
/// secondary value); by default the scrim does nothing, since the dialog
/// asks for a decision.
Future<T?> showFsDialog<T>(
  BuildContext context, {
  required PrDialog<T> dialog,
  bool barrierDismissible = false,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierColor: PrColors.of(context).scrim,
    transitionDuration: PrMotion.slow,
    pageBuilder: (context, animation, secondaryAnimation) {
      final centred = Center(child: dialog);
      if (!barrierDismissible) return centred;
      // Not the route's own dismissible barrier: that pops with null,
      // where the scrim should answer the secondary value like Esc.
      void answer() => dialog._answer(context, dialog.secondary);
      return Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
            onTap: answer,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: answer,
            ),
          ),
          centred,
        ],
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: PrMotion.enter,
            reverseCurve: PrMotion.exit,
          ),
          child: child,
        ),
  );
}

/// A focus scope whose Tab order wraps around inside it.
class _TrapFocus extends StatefulWidget {
  const _TrapFocus({required this.child});

  final Widget child;

  @override
  State<_TrapFocus> createState() => _TrapFocusState();
}

class _TrapFocusState extends State<_TrapFocus> {
  final _node = FocusScopeNode(
    debugLabel: 'PrDialog',
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FocusScope(node: _node, child: widget.child);
}

/// Gives the primary button initial focus unless something in the dialog
/// asked for it first.
///
/// A text field's `autofocus` lands after the first frame (EditableText
/// defers it), so the primary's request is queued after the frame too,
/// from a build that runs after the content's: the first request wins.
class _InitialFocus extends StatefulWidget {
  const _InitialFocus({required this.builder});

  final Widget Function(FocusNode node) builder;

  @override
  State<_InitialFocus> createState() => _InitialFocusState();
}

class _InitialFocusState extends State<_InitialFocus> {
  final _node = FocusNode(debugLabel: 'PrDialog primary');
  bool _scheduled = false;

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_scheduled) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) FocusScope.of(context).autofocus(_node);
      });
    }
    return widget.builder(_node);
  }
}
