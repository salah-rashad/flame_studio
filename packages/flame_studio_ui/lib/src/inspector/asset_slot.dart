import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../icons.dart';
import 'slot.dart';

/// A reference to a project file (image, sprite sheet, audio, font, JSON):
/// a thumbnail or type icon, the file name, browse and clear buttons, and a
/// drop target. The editor of an asset field's `FsPropertyRow`.
///
/// - 20px; a 16px [thumbnail] (`radius-xs`, the app builds the image) or
///   the [typeIcon]; the [fileName] in mono; browse (folder) and, when
///   filled, clear (×).
/// - Empty: [placeholder] ("None (Sprite)") in `text-placeholder`.
/// - **Drop target:** a payload [willAccept] accepts, under the pointer or
///   in flight ([dragInFlight]), gives the `accent-subtle` fill, the
///   `accent-text` edge and the [dropHint] ("Drop coin.png here"). A
///   rejected payload under the pointer gives the `error` edge and the
///   not-allowed cursor; ignored payloads change nothing.
/// - **Missing** (file moved or deleted): `error-subtle` fill,
///   `error-border` edge, an alert icon for the thumbnail, the old name in
///   `error` and the [missingLabel] badge, so the user can find it.
/// - Mixed: [mixedLabel] ("— (2 different)"). Disabled: flat,
///   `text-disabled`.
/// - Click the name to reveal it ([onReveal]), double-click to open it
///   ([onOpen]); a click on the placeholder browses. Enter or Space browses,
///   ⌫ clears while focused.
///
/// `D` is the drag payload type the app uses. Part for `FsDebugStates`:
/// `drop` (see `FsSlot`).
class FsAssetSlot<D extends Object> extends StatelessWidget {
  /// Creates the slot.
  const FsAssetSlot({
    super.key,
    required this.fileName,
    required this.placeholder,
    this.thumbnail,
    this.typeIcon = FsIcons.image,
    this.missing = false,
    this.missingLabel,
    this.mixed = false,
    this.mixedLabel,
    this.onBrowse,
    this.browseTooltip,
    this.onClear,
    this.clearTooltip,
    this.onReveal,
    this.onOpen,
    this.willAccept,
    this.onDrop,
    this.dropHint,
    this.dragInFlight,
    this.enabled = true,
    this.focusNode,
  });

  /// The file's name; null for empty.
  final String? fileName;

  /// Shown while empty: "None (Sprite)".
  final String placeholder;

  /// A 16px image of the file; wins over [typeIcon] while filled.
  final Widget? thumbnail;

  /// The kind of asset (image, music, file).
  final IconData typeIcon;

  /// The file was moved or deleted; [fileName] stays visible.
  final bool missing;

  /// The badge while [missing] ("Missing").
  final String? missingLabel;

  /// The selected objects disagree.
  final bool mixed;

  /// Shown while [mixed] ("— (2 different)").
  final String? mixedLabel;

  /// Opens a file chooser: the folder button, Enter, or a click on the
  /// placeholder.
  final VoidCallback? onBrowse;

  /// The folder button's tooltip.
  final String? browseTooltip;

  /// Clears the reference: the × button and ⌫.
  final VoidCallback? onClear;

  /// The × button's tooltip.
  final String? clearTooltip;

  /// A click on the name: reveal the file in the Assets panel.
  final VoidCallback? onReveal;

  /// A double click on the name: open the file.
  final VoidCallback? onOpen;

  /// Whether a dragged payload fits.
  final FsDropAcceptance Function(D data)? willAccept;

  /// A fitting payload was dropped.
  final ValueChanged<D>? onDrop;

  /// The drop target's text ("Drop coin.png here").
  final String Function(D data)? dropHint;

  /// The app's drag in progress, so every fitting slot lights up.
  final ValueListenable<D?>? dragInFlight;

  /// False disables the slot.
  final bool enabled;

  /// The focus node.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final filled = fileName != null && !mixed;
    return FsSlot<D>(
      icon: typeIcon,
      thumbnail: thumbnail,
      name: fileName,
      placeholder: placeholder,
      missing: missing,
      missingLabel: missingLabel,
      mixed: mixed,
      mixedLabel: mixedLabel,
      actions: [
        FsSlotAction(
          icon: FsIcons.folder,
          tooltip: browseTooltip ?? '',
          onPressed: onBrowse,
        ),
      ],
      onClear: onClear,
      clearTooltip: clearTooltip,
      onActivate: onBrowse,
      onNameTap: filled ? onReveal : onBrowse,
      onNameDoubleTap: onOpen,
      willAccept: willAccept,
      onDrop: onDrop,
      dropHint: dropHint,
      dragInFlight: dragInFlight,
      enabled: enabled,
      focusNode: focusNode,
      semanticsLabel: mixed ? mixedLabel : (fileName ?? placeholder),
    );
  }
}
