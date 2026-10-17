/// The Flame Studio design system in Flutter: tokens, theme and the editor's
/// widgets.
///
/// Presentation only (Q83): widgets take plain values and callbacks and know
/// nothing about scenes, the document or Riverpod; the app wires them to its
/// state. The tokens mirror `design/tokens.json`, exported from the design
/// system made in Claude Design.
library;

export 'src/colors.dart';
export 'src/foundation/anchored_overlay.dart';
export 'src/foundation/debug_states.dart';
export 'src/foundation/field_box.dart';
export 'src/foundation/focus_ring.dart' show FsFocusRing;
export 'src/foundation/interactive.dart';
export 'src/foundation/number_editing.dart' show FsNumberKind;
export 'src/foundation/panel_focus.dart';
export 'src/foundation/scrub.dart' show FsScrubHandle;
export 'src/foundation/shortcut_label.dart';
export 'src/foundation/value_source.dart';
export 'src/icons.dart';
export 'src/inspector/number_property.dart';
export 'src/inspector/property_row.dart' show FsPropertyRow;
export 'src/inspector/vector2_property.dart';
export 'src/metrics.dart';
export 'src/shadows.dart';
export 'src/structure/tree_row.dart' hide FsDropPainter;
export 'src/theme.dart';
export 'src/typography.dart';
