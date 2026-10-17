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

/// A [FsDialog] button: its label and the value the dialog returns when it
/// is pressed.
@immutable
class FsDialogAction<T> {
  /// Creates the action.
  const FsDialogAction({required this.label, this.value});

  /// A verb that answers the title: "Save", "Don't save", "Cancel".
  final String label;

  /// What `showFsDialog` returns for this button.
  final T? value;
}

/// The two dialog widths.
enum FsDialogWidth {
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
/// Parts for `FsDebugStates` (all exact): `primary`, `secondary`,
/// `destructive` and `close`, the states of each button.
class FsDialog<T> extends StatelessWidget {
  /// Creates the dialog.
  const FsDialog({
    super.key,
    required this.title,
    this.body,
    this.content,
    required this.primary,
    this.secondary,
    this.destructive,
    this.width = FsDialogWidth.regular,
    this.closeTooltip,
  });

  /// A question or an action: "Save changes to level_1.scene?".
  final String title;

  /// The explanation, in `text-secondary`.
  final String? body;

  /// Fields or a checkbox under the [body].
  final Widget? content;

  /// The answer the dialog is for; initial focus, answers Enter.
  final FsDialogAction<T> primary;

  /// "Cancel"; also Esc and the close ×.
  final FsDialogAction<T>? secondary;

  /// The destructive answer ("Don't save"), on the left, apart.
  final FsDialogAction<T>? destructive;

  /// 440, or 560 for forms.
  final FsDialogWidth width;

  /// The close ×'s tooltip and semantics label ("Close").
  final String? closeTooltip;

  void _answer(BuildContext context, FsDialogAction<T>? action) {
    // maybePop: a dialog drawn inline (the gallery) sits on the first
    // route, which this leaves alone.
    unawaited(Navigator.of(context).maybePop<T>(action?.value));
  }

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    Widget part(String name, Widget child) => FsDebugStates(
      states: FsDebugStates.of(context, part: name, exact: true),
      child: child,
    );

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        FsSpacing.s4,
        FsSpacing.s4,
        FsSpacing.s3,
        0,
      ),
      child: Row(
        spacing: FsSpacing.s2,
        children: [
          Expanded(
            child: Text(
              title,
              style: FsText.title.copyWith(color: c.textPrimary),
            ),
          ),
          part(
            'close',
            FsIconButton(
              icon: FsIcons.x,
              iconSize: FsSizes.iconSm,
              size: FsIconButtonSize.small,
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
        FsSpacing.s4,
        FsSpacing.s2,
        FsSpacing.s4,
        FsSpacing.s4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: FsSpacing.s3,
        children: [
          if (body != null)
            Text(body!, style: FsText.body.copyWith(color: c.textSecondary)),
          if (content != null)
            DefaultTextStyle(
              style: FsText.body.copyWith(color: c.textPrimary),
              child: content!,
            ),
        ],
      ),
    );

    final footer = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FsSpacing.s4,
        vertical: FsSpacing.s3,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.borderOverlay)),
      ),
      child: Row(
        spacing: FsSpacing.s2,
        children: [
          if (destructive case final action?)
            part(
              'destructive',
              FsButton(
                label: action.label,
                variant: FsButtonVariant.danger,
                onPressed: () => _answer(context, action),
              ),
            ),
          const Spacer(),
          if (secondary case final action?)
            part(
              'secondary',
              FsButton(
                label: action.label,
                onPressed: () => _answer(context, action),
              ),
            ),
          part(
            'primary',
            _InitialFocus(
              builder: (node) => FsButton(
                label: primary.label,
                variant: FsButtonVariant.primary,
                focusNode: node,
                onPressed: () => _answer(context, primary),
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
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
                FsDialogWidth.regular => 440,
                FsDialogWidth.form => 560,
              },
              decoration: BoxDecoration(
                color: c.surfaceOverlay,
                border: Border.all(color: c.borderOverlay),
                borderRadius: FsRadii.lg,
                boxShadow: FsShadows.of(context).dialog,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  if (hasBody)
                    bodyPart
                  else
                    const SizedBox(height: FsSpacing.s4),
                  footer,
                ],
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
/// The scrim doesn't close the dialog: it asks for a decision.
Future<T?> showFsDialog<T>(
  BuildContext context, {
  required FsDialog<T> dialog,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierColor: FsColors.of(context).scrim,
    transitionDuration: FsMotion.slow,
    pageBuilder: (context, animation, secondaryAnimation) =>
        Center(child: dialog),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: FsMotion.enter,
            reverseCurve: FsMotion.exit,
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
    debugLabel: 'FsDialog',
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
  final _node = FocusNode(debugLabel: 'FsDialog primary');
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
