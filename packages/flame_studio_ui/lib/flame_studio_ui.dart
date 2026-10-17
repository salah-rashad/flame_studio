/// The Flame Studio design system in Flutter: tokens, theme and the editor's
/// widgets.
///
/// Presentation only (Q83): widgets take plain values and callbacks and know
/// nothing about scenes, the document or Riverpod; the app wires them to its
/// state. The tokens mirror `design/tokens.json`, exported from the design
/// system made in Claude Design.
library;

export 'src/actions/button.dart';
export 'src/actions/icon_button.dart';
export 'src/actions/segmented_control.dart';
export 'src/actions/split_button.dart';
export 'src/actions/toggle_button.dart';
export 'src/colors.dart';
export 'src/floating/context_menu.dart';
export 'src/floating/tooltip.dart';
export 'src/foundation/anchored_overlay.dart';
export 'src/foundation/debug_states.dart';
export 'src/foundation/field_box.dart';
export 'src/foundation/focus_ring.dart' show FsFocusRing;
export 'src/foundation/interactive.dart';
export 'src/foundation/number_editing.dart' show FsNumberKind;
export 'src/foundation/panel_focus.dart';
export 'src/foundation/platform_hooks.dart';
export 'src/foundation/scrub.dart' show FsScrubHandle;
export 'src/foundation/shortcut_label.dart';
export 'src/foundation/value_source.dart';
export 'src/icons.dart';
export 'src/inputs/checkbox.dart' hide FsCheckMarkPainter;
export 'src/inputs/dropdown.dart';
export 'src/inputs/number_field.dart';
export 'src/inputs/search_field.dart';
export 'src/inputs/text_field.dart';
export 'src/inspector/asset_slot.dart';
export 'src/inspector/bool_property.dart';
export 'src/inspector/color_picker.dart' show FsColorPicker;
export 'src/inspector/color_property.dart';
export 'src/inspector/entity_slot.dart';
export 'src/inspector/number_property.dart';
export 'src/inspector/property_row.dart' show FsPropertyList, FsPropertyRow;
export 'src/inspector/slot.dart' show FsDragInFlight, FsDropAcceptance;
export 'src/inspector/vector2_property.dart';
export 'src/metrics.dart';
export 'src/shadows.dart';
export 'src/status/badge.dart';
export 'src/structure/panel.dart';
export 'src/structure/section_header.dart';
export 'src/structure/tabs.dart';
export 'src/structure/tree_row.dart' hide FsDropPainter;
export 'src/theme.dart';
export 'src/typography.dart';
