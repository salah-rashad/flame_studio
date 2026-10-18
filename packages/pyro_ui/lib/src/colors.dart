import 'package:flutter/material.dart';

/// The colour tokens of the Pyro design system.
///
/// Mirrors `color.tokens` in `design/tokens.json` one to one (token
/// `surface-panel` is [surfacePanel]); `test/tokens_test.dart` fails if they
/// drift. Only a dark theme exists so far ([PrColors.dark]); a light theme
/// adds a second constant with the same fields.
///
/// Read it with `PrColors.of(context)`; widgets never use hex literals.
@immutable
class PrColors extends ThemeExtension<PrColors> {
  /// Creates a colour set. Use [PrColors.dark] unless you are adding a theme.
  const PrColors({
    required this.bgApp,
    required this.bgViewport,
    required this.surfacePanel,
    required this.surfaceRaised,
    required this.surfaceInput,
    required this.surfaceHover,
    required this.surfacePressed,
    required this.surfaceSelected,
    required this.surfaceSelectedInactive,
    required this.surfaceOverlay,
    required this.borderSubtle,
    required this.borderControl,
    required this.borderStrong,
    required this.borderOverlay,
    required this.textPrimary,
    required this.textSecondary,
    required this.textPlaceholder,
    required this.textDisabled,
    required this.textOnAccent,
    required this.accent,
    required this.accentHover,
    required this.accentPressed,
    required this.accentText,
    required this.accentSubtle,
    required this.focusRing,
    required this.success,
    required this.successSubtle,
    required this.successBorder,
    required this.warning,
    required this.warningSubtle,
    required this.warningBorder,
    required this.error,
    required this.errorSubtle,
    required this.errorBorder,
    required this.info,
    required this.infoSubtle,
    required this.infoBorder,
    required this.prefab,
    required this.prefabSubtle,
    required this.axisX,
    required this.axisY,
    required this.statusIdle,
    required this.scrim,
  });

  /// The dark theme, the only one so far.
  static const dark = PrColors(
    bgApp: Color(0xFF141518),
    bgViewport: Color(0xFF0E0F11),
    surfacePanel: Color(0xFF1C1D21),
    surfaceRaised: Color(0xFF232429),
    surfaceInput: Color(0xFF16171A),
    surfaceHover: Color(0xFF2C2D33),
    surfacePressed: Color(0xFF34363D),
    surfaceSelected: Color(0xFF4A2A18),
    surfaceSelectedInactive: Color(0xFF33353C),
    surfaceOverlay: Color(0xFF26272D),
    borderSubtle: Color(0xFF2A2B30),
    borderControl: Color(0xFF6E717A),
    borderStrong: Color(0xFF8A8D96),
    borderOverlay: Color(0xFF3D3F46),
    textPrimary: Color(0xFFE7E8EB),
    textSecondary: Color(0xFFA4A7B0),
    textPlaceholder: Color(0xFF868993),
    textDisabled: Color(0xFF62656D),
    textOnAccent: Color(0xFFFFFFFF),
    accent: Color(0xFFC4450F),
    accentHover: Color(0xFFCF4A10),
    accentPressed: Color(0xFFA8380A),
    accentText: Color(0xFFFF9A5C),
    accentSubtle: Color(0xFF3A2314),
    focusRing: Color(0xFFFFA66E),
    success: Color(0xFF4FC98D),
    successSubtle: Color(0xFF16301F),
    successBorder: Color(0xFF2B5A3E),
    warning: Color(0xFFE9C46A),
    warningSubtle: Color(0xFF352C12),
    warningBorder: Color(0xFF6A5524),
    error: Color(0xFFFF6E6E),
    errorSubtle: Color(0xFF3A1B1D),
    errorBorder: Color(0xFF7A3236),
    info: Color(0xFF6CB2F5),
    infoSubtle: Color(0xFF162A3D),
    infoBorder: Color(0xFF2C5478),
    prefab: Color(0xFF6CC7D6),
    prefabSubtle: Color(0xFF14303A),
    axisX: Color(0xFFF26D6D),
    axisY: Color(0xFF72CF6A),
    statusIdle: Color(0xFF7B7E87),
    scrim: Color(0xA3000000),
  );

  /// The colours of the nearest [Theme].
  ///
  /// Throws if the theme has no [PrColors]: build it with `PrTheme`.
  static PrColors of(BuildContext context) =>
      Theme.of(context).extension<PrColors>()!;

  /// Deepest chrome: window background, title bar, status bar, and the 1px gaps
  /// that separate docked panels.
  final Color bgApp;

  /// Empty canvas behind the game in the scene viewport. Never used for chrome.
  final Color bgViewport;

  /// Body of every docked panel (scene tree, inspector, console). The default
  /// ground for text.
  final Color surfacePanel;

  /// Panel headers, toolbars, tab strips and collapsible section headers — one
  /// step above surface-panel.
  final Color surfaceRaised;

  /// Fill of text, number, search and dropdown fields, checkboxes and
  /// segmented-control tracks — sunk below the panel.
  final Color surfaceInput;

  /// Hover fill for rows, ghost buttons, tabs, menu-less list items.
  final Color surfaceHover;

  /// Pressed fill for secondary/ghost buttons; slider and switch tracks at
  /// rest.
  final Color surfacePressed;

  /// Selected row or item while its panel has keyboard focus (ember-tinted).
  final Color surfaceSelected;

  /// Selected row or item while its panel does NOT have focus.
  final Color surfaceSelectedInactive;

  /// Floating layers: context menus, dropdown lists, tooltips, toasts, dialogs.
  /// Always paired with border-overlay and a shadow token.
  final Color surfaceOverlay;

  /// Dividers inside a panel: toolbar group separators, list dividers, section
  /// edges. Decorative only.
  final Color borderSubtle;

  /// Resting border of fields, checkboxes, secondary buttons and segmented
  /// controls. Meets 3:1 on surface-panel, surface-raised and surface-overlay.
  final Color borderControl;

  /// Hover border of fields and secondary buttons.
  final Color borderStrong;

  /// 1px edge of floating layers (menus, tooltips, toasts, dialogs).
  final Color borderOverlay;

  /// Default text and icons. 10:1+ on every surface, including surface-
  /// selected.
  final Color textPrimary;

  /// Property labels, metadata, inactive tabs, idle icons, values left at their
  /// code default. 5:1+ on every surface.
  final Color textSecondary;

  /// Placeholder and empty-slot text ("None (Sprite)"). 5.1:1 on surface-input
  /// and 4.8:1 on surface-panel — use it only on those two.
  final Color textPlaceholder;

  /// Disabled labels, values and icons. Intentionally below 4.5:1 (WCAG exempts
  /// inactive controls).
  final Color textDisabled;

  /// Labels and icons on an accent fill (primary button, Play, highlighted menu
  /// item). 5:1 on accent, 4.5:1 on accent-hover.
  final Color textOnAccent;

  /// Ember. Primary button fill, Play button, highlighted menu item, checked
  /// checkbox and switch. At most one primary button per view.
  final Color accent;

  /// Hover fill of accent controls.
  final Color accentHover;

  /// Pressed fill of accent controls.
  final Color accentPressed;

  /// Ember as a foreground: active tool icon, active tab indicator, drop-target
  /// edges and insertion lines, links, overridden-value marker. 8:1 on surface-
  /// panel.
  final Color accentText;

  /// Ember wash behind accent-text: active toggle and segment, drop-target
  /// fill, selected device chip.
  final Color accentSubtle;

  /// Keyboard focus ring (2px, solid). 6:1+ on every surface, so it reads even
  /// on surface-selected and accent fills.
  final Color focusRing;

  /// Success icons and text: console OK lines, status-dot ok, success toast.
  /// Always paired with a check icon or a word.
  final Color success;

  /// Fill behind success text (badges, banners).
  final Color successSubtle;

  /// 1px edge of a success banner.
  final Color successBorder;

  /// Warning icons and text: console warnings, warning-count badge, warning
  /// banner. Always paired with the triangle icon.
  final Color warning;

  /// Fill behind warning text.
  final Color warningSubtle;

  /// 1px edge of a warning banner.
  final Color warningBorder;

  /// Errors: console errors, invalid field border, "missing" badges and slots.
  /// Always paired with the alert-circle icon or a word.
  final Color error;

  /// Fill behind error text; fill of a missing reference slot.
  final Color errorSubtle;

  /// 1px edge of an error banner.
  final Color errorBorder;

  /// Info icons and text, status-dot working, hot-reload progress.
  final Color info;

  /// Fill behind info text.
  final Color infoSubtle;

  /// 1px edge of an info banner.
  final Color infoBorder;

  /// Prefab badge text and prefab node names in the tree. Not a status colour.
  final Color prefab;

  /// Fill behind the prefab badge.
  final Color prefabSubtle;

  /// X axis: the X label of Vector2 fields and the X handle of the move gizmo.
  final Color axisX;

  /// Y axis: the Y label of Vector2 fields and the Y handle of the move gizmo.
  final Color axisY;

  /// Status dot: idle. Always beside a text label.
  final Color statusIdle;

  /// Dims the editor behind a modal dialog.
  final Color scrim;

  @override
  PrColors copyWith({
    Color? bgApp,
    Color? bgViewport,
    Color? surfacePanel,
    Color? surfaceRaised,
    Color? surfaceInput,
    Color? surfaceHover,
    Color? surfacePressed,
    Color? surfaceSelected,
    Color? surfaceSelectedInactive,
    Color? surfaceOverlay,
    Color? borderSubtle,
    Color? borderControl,
    Color? borderStrong,
    Color? borderOverlay,
    Color? textPrimary,
    Color? textSecondary,
    Color? textPlaceholder,
    Color? textDisabled,
    Color? textOnAccent,
    Color? accent,
    Color? accentHover,
    Color? accentPressed,
    Color? accentText,
    Color? accentSubtle,
    Color? focusRing,
    Color? success,
    Color? successSubtle,
    Color? successBorder,
    Color? warning,
    Color? warningSubtle,
    Color? warningBorder,
    Color? error,
    Color? errorSubtle,
    Color? errorBorder,
    Color? info,
    Color? infoSubtle,
    Color? infoBorder,
    Color? prefab,
    Color? prefabSubtle,
    Color? axisX,
    Color? axisY,
    Color? statusIdle,
    Color? scrim,
  }) {
    return PrColors(
      bgApp: bgApp ?? this.bgApp,
      bgViewport: bgViewport ?? this.bgViewport,
      surfacePanel: surfacePanel ?? this.surfacePanel,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceInput: surfaceInput ?? this.surfaceInput,
      surfaceHover: surfaceHover ?? this.surfaceHover,
      surfacePressed: surfacePressed ?? this.surfacePressed,
      surfaceSelected: surfaceSelected ?? this.surfaceSelected,
      surfaceSelectedInactive:
          surfaceSelectedInactive ?? this.surfaceSelectedInactive,
      surfaceOverlay: surfaceOverlay ?? this.surfaceOverlay,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderControl: borderControl ?? this.borderControl,
      borderStrong: borderStrong ?? this.borderStrong,
      borderOverlay: borderOverlay ?? this.borderOverlay,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textPlaceholder: textPlaceholder ?? this.textPlaceholder,
      textDisabled: textDisabled ?? this.textDisabled,
      textOnAccent: textOnAccent ?? this.textOnAccent,
      accent: accent ?? this.accent,
      accentHover: accentHover ?? this.accentHover,
      accentPressed: accentPressed ?? this.accentPressed,
      accentText: accentText ?? this.accentText,
      accentSubtle: accentSubtle ?? this.accentSubtle,
      focusRing: focusRing ?? this.focusRing,
      success: success ?? this.success,
      successSubtle: successSubtle ?? this.successSubtle,
      successBorder: successBorder ?? this.successBorder,
      warning: warning ?? this.warning,
      warningSubtle: warningSubtle ?? this.warningSubtle,
      warningBorder: warningBorder ?? this.warningBorder,
      error: error ?? this.error,
      errorSubtle: errorSubtle ?? this.errorSubtle,
      errorBorder: errorBorder ?? this.errorBorder,
      info: info ?? this.info,
      infoSubtle: infoSubtle ?? this.infoSubtle,
      infoBorder: infoBorder ?? this.infoBorder,
      prefab: prefab ?? this.prefab,
      prefabSubtle: prefabSubtle ?? this.prefabSubtle,
      axisX: axisX ?? this.axisX,
      axisY: axisY ?? this.axisY,
      statusIdle: statusIdle ?? this.statusIdle,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  PrColors lerp(PrColors? other, double t) {
    if (other == null) return this;
    return PrColors(
      bgApp: Color.lerp(bgApp, other.bgApp, t)!,
      bgViewport: Color.lerp(bgViewport, other.bgViewport, t)!,
      surfacePanel: Color.lerp(surfacePanel, other.surfacePanel, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceInput: Color.lerp(surfaceInput, other.surfaceInput, t)!,
      surfaceHover: Color.lerp(surfaceHover, other.surfaceHover, t)!,
      surfacePressed: Color.lerp(surfacePressed, other.surfacePressed, t)!,
      surfaceSelected: Color.lerp(surfaceSelected, other.surfaceSelected, t)!,
      surfaceSelectedInactive: Color.lerp(
        surfaceSelectedInactive,
        other.surfaceSelectedInactive,
        t,
      )!,
      surfaceOverlay: Color.lerp(surfaceOverlay, other.surfaceOverlay, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderControl: Color.lerp(borderControl, other.borderControl, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      borderOverlay: Color.lerp(borderOverlay, other.borderOverlay, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textPlaceholder: Color.lerp(textPlaceholder, other.textPlaceholder, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      textOnAccent: Color.lerp(textOnAccent, other.textOnAccent, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      accentPressed: Color.lerp(accentPressed, other.accentPressed, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      accentSubtle: Color.lerp(accentSubtle, other.accentSubtle, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSubtle: Color.lerp(successSubtle, other.successSubtle, t)!,
      successBorder: Color.lerp(successBorder, other.successBorder, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSubtle: Color.lerp(warningSubtle, other.warningSubtle, t)!,
      warningBorder: Color.lerp(warningBorder, other.warningBorder, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorSubtle: Color.lerp(errorSubtle, other.errorSubtle, t)!,
      errorBorder: Color.lerp(errorBorder, other.errorBorder, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSubtle: Color.lerp(infoSubtle, other.infoSubtle, t)!,
      infoBorder: Color.lerp(infoBorder, other.infoBorder, t)!,
      prefab: Color.lerp(prefab, other.prefab, t)!,
      prefabSubtle: Color.lerp(prefabSubtle, other.prefabSubtle, t)!,
      axisX: Color.lerp(axisX, other.axisX, t)!,
      axisY: Color.lerp(axisY, other.axisY, t)!,
      statusIdle: Color.lerp(statusIdle, other.statusIdle, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}
