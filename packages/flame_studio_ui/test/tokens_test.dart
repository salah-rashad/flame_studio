// Checks the Dart tokens against design/tokens.json, the copy of the design
// system's tokens. After re-exporting tokens.json from Claude Design, run this
// and update the Dart side until it passes.
import 'dart:convert';
import 'dart:io';

import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final Map<String, Object?> _tokens =
    jsonDecode(File('design/tokens.json').readAsStringSync())
        as Map<String, Object?>;

List<Map<String, Object?>> _family(String name) =>
    ((_tokens[name]! as Map<String, Object?>)['tokens']! as List<Object?>)
        .cast<Map<String, Object?>>();

String _darkValue(Map<String, Object?> token) {
  final value = token['value'];
  return value is String
      ? value
      : (value! as Map<String, Object?>)['dark']! as String;
}

/// `#rrggbb` or `#rrggbbaa` as ARGB.
int _argb(String hex) {
  final h = hex.substring(1);
  final rgb = int.parse(h.substring(0, 6), radix: 16);
  final alpha = h.length == 8 ? int.parse(h.substring(6), radix: 16) : 0xFF;
  return alpha << 24 | rgb;
}

double _px(String value) => double.parse(value.replaceAll('px', ''));

void main() {
  test('every colour token matches FsColors.dark, and nothing else exists', () {
    const c = FsColors.dark;
    final dart = <String, Color>{
      'bg-app': c.bgApp,
      'bg-viewport': c.bgViewport,
      'surface-panel': c.surfacePanel,
      'surface-raised': c.surfaceRaised,
      'surface-input': c.surfaceInput,
      'surface-hover': c.surfaceHover,
      'surface-pressed': c.surfacePressed,
      'surface-selected': c.surfaceSelected,
      'surface-selected-inactive': c.surfaceSelectedInactive,
      'surface-overlay': c.surfaceOverlay,
      'border-subtle': c.borderSubtle,
      'border-control': c.borderControl,
      'border-strong': c.borderStrong,
      'border-overlay': c.borderOverlay,
      'text-primary': c.textPrimary,
      'text-secondary': c.textSecondary,
      'text-placeholder': c.textPlaceholder,
      'text-disabled': c.textDisabled,
      'text-on-accent': c.textOnAccent,
      'accent': c.accent,
      'accent-hover': c.accentHover,
      'accent-pressed': c.accentPressed,
      'accent-text': c.accentText,
      'accent-subtle': c.accentSubtle,
      'focus-ring': c.focusRing,
      'success': c.success,
      'success-subtle': c.successSubtle,
      'success-border': c.successBorder,
      'warning': c.warning,
      'warning-subtle': c.warningSubtle,
      'warning-border': c.warningBorder,
      'error': c.error,
      'error-subtle': c.errorSubtle,
      'error-border': c.errorBorder,
      'info': c.info,
      'info-subtle': c.infoSubtle,
      'info-border': c.infoBorder,
      'prefab': c.prefab,
      'prefab-subtle': c.prefabSubtle,
      'axis-x': c.axisX,
      'axis-y': c.axisY,
      'status-idle': c.statusIdle,
      'scrim': c.scrim,
    };
    final json = {
      for (final t in _family('color')) t['name']! as String: _darkValue(t),
    };
    expect(dart.keys.toSet(), json.keys.toSet());
    for (final MapEntry(:key, :value) in json.entries) {
      expect(dart[key]!.toARGB32(), _argb(value), reason: key);
    }
  });

  test('shadow tokens match FsShadows.dark', () {
    const s = FsShadows.dark;
    final dart = {
      'shadow-tooltip': s.tooltip.single,
      'shadow-popover': s.popover.single,
      'shadow-dialog': s.dialog.single,
      'shadow-focus': s.focus.single,
    };
    final json = {
      for (final t in _family('shadow')) t['name']! as String: _darkValue(t),
    };
    expect({...dart.keys, 'shadow-focus-inset'}, json.keys.toSet());

    for (final MapEntry(:key, :value) in dart.entries) {
      // "x y blur [spread] #color"
      final parts = json[key]!.split(' ');
      final lengths = parts.sublist(0, parts.length - 1).map(_px).toList();
      expect(value.offset, Offset(lengths[0], lengths[1]), reason: key);
      expect(value.blurRadius, lengths[2], reason: key);
      expect(
        value.spreadRadius,
        lengths.length > 3 ? lengths[3] : 0,
        reason: key,
      );
      expect(value.color.toARGB32(), _argb(parts.last), reason: key);
    }

    // "inset 0 0 0 2px #color": drawn as a border, see FsShadows.focusInset.
    final inset = json['shadow-focus-inset']!.split(' ');
    expect(inset.first, 'inset');
    expect(s.focusInset.width, _px(inset[4]));
    expect(s.focusInset.color.toARGB32(), _argb(inset.last));
  });

  test('spacing, radius and size tokens match', () {
    final dart = <String, double>{
      'space-1': FsSpacing.s1,
      'space-2': FsSpacing.s2,
      'space-3': FsSpacing.s3,
      'space-4': FsSpacing.s4,
      'space-6': FsSpacing.s6,
      'space-8': FsSpacing.s8,
      'radius-xs': FsRadii.xs.topLeft.x,
      'radius-sm': FsRadii.sm.topLeft.x,
      'radius-md': FsRadii.md.topLeft.x,
      'radius-lg': FsRadii.lg.topLeft.x,
      'radius-full': FsRadii.full.topLeft.x,
      'size-row-tree': FsSizes.rowTree,
      'size-row-property': FsSizes.rowProperty,
      'size-control-sm': FsSizes.controlSm,
      'size-control': FsSizes.control,
      'size-toolbar': FsSizes.toolbar,
      'size-tab': FsSizes.tab,
      'size-titlebar': FsSizes.titlebar,
      'size-statusbar': FsSizes.statusbar,
      'size-icon': FsSizes.icon,
      'size-icon-sm': FsSizes.iconSm,
    };
    final json = {
      for (final family in ['spacing', 'radius', 'size'])
        for (final t in _family(family))
          t['name']! as String: _px(t['value']! as String),
    };
    expect(dart, json);
  });

  test('text styles match the type scale', () {
    final dart = <String, TextStyle>{
      'title': FsText.title,
      'heading': FsText.heading,
      'body': FsText.body,
      'body-strong': FsText.bodyStrong,
      'section': FsText.section,
      'small': FsText.small,
      'caption': FsText.caption,
      'mono': FsText.mono,
      'mono-console': FsText.monoConsole,
      'mono-small': FsText.monoSmall,
    };
    final type = _tokens['type']! as Map<String, Object?>;
    final families = {'ui': FsText.uiFamily, 'mono': FsText.monoFamily};
    final seen = <String>{};
    for (final group
        in (type['groups']! as List<Object?>).cast<Map<String, Object?>>()) {
      final family = families[group['family']]!;
      for (final s
          in (group['styles']! as List<Object?>).cast<Map<String, Object?>>()) {
        final name = s['name']! as String;
        final style = dart[name]!;
        seen.add(name);
        expect(style.fontFamily, family, reason: name);
        expect(style.fontSize, _px(s['fontSize']! as String), reason: name);
        expect(
          style.fontSize! * style.height!,
          closeTo(_px(s['lineHeight']! as String), 1e-9),
          reason: name,
        );
        expect(style.fontWeight!.value, s['fontWeight'], reason: name);
      }
    }
    expect(seen, dart.keys.toSet());
  });
}
