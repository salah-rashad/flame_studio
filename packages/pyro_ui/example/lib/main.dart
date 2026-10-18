import 'package:flutter/material.dart';
import 'package:pyro_ui/pyro_ui.dart';

import 'pages/asset_slot_page.dart';
import 'pages/badge_page.dart';
import 'pages/banner_page.dart';
import 'pages/bool_property_page.dart';
import 'pages/button_page.dart';
import 'pages/color_picker_page.dart';
import 'pages/color_property_page.dart';
import 'pages/context_menu_page.dart';
import 'pages/dialog_page.dart';
import 'pages/dropdown_page.dart';
import 'pages/editor_shell_page.dart';
import 'pages/empty_state_page.dart';
import 'pages/entity_slot_page.dart';
import 'pages/foundations_page.dart';
import 'pages/icon_button_page.dart';
import 'pages/icons_page.dart';
import 'pages/number_field_page.dart';
import 'pages/number_property_page.dart';
import 'pages/overlay_page.dart';
import 'pages/panel_page.dart';
import 'pages/progress_page.dart';
import 'pages/property_row_page.dart';
import 'pages/search_field_page.dart';
import 'pages/section_header_page.dart';
import 'pages/segmented_control_page.dart';
import 'pages/shortcut_label_page.dart';
import 'pages/split_button_page.dart';
import 'pages/tabs_page.dart';
import 'pages/text_field_page.dart';
import 'pages/toast_page.dart';
import 'pages/toggle_button_page.dart';
import 'pages/toolbar_page.dart';
import 'pages/tooltip_page.dart';
import 'pages/tree_row_page.dart';
import 'pages/vector2_property_page.dart';

void main() => runApp(const GalleryApp());

/// One gallery page. [reviewed] records the side-by-side check against the
/// component's preview.html (plan §6.1); flip it when the page matches.
class GalleryEntry {
  const GalleryEntry(
    this.group,
    this.name,
    this.build, {
    this.reviewed = false,
  });

  final String group;
  final String name;
  final Widget Function() build;
  final bool reviewed;
}

/// Every gallery page, in sidebar order. The golden test renders each one.
const galleryPages = <GalleryEntry>[
  GalleryEntry('Foundations', 'Icons', IconsPage.new),
  GalleryEntry('Foundations', 'Field box · Interactive', FoundationsPage.new),
  GalleryEntry('Foundations', 'Anchored overlay', OverlayPage.new),
  GalleryEntry('Foundations', 'Shortcut label', ShortcutLabelPage.new),
  GalleryEntry('Actions', 'Button', ButtonPage.new, reviewed: true),
  GalleryEntry('Actions', 'IconButton', IconButtonPage.new, reviewed: true),
  GalleryEntry('Actions', 'ToggleButton', ToggleButtonPage.new, reviewed: true),
  GalleryEntry(
    'Actions',
    'SegmentedControl',
    SegmentedControlPage.new,
    reviewed: true,
  ),
  GalleryEntry('Actions', 'SplitButton', SplitButtonPage.new, reviewed: true),
  GalleryEntry('Actions', 'Toolbar', ToolbarPage.new, reviewed: true),
  GalleryEntry('Inputs', 'TextField', TextFieldPage.new, reviewed: true),
  GalleryEntry('Inputs', 'Dropdown', DropdownPage.new, reviewed: true),
  GalleryEntry('Inputs', 'SearchField', SearchFieldPage.new, reviewed: true),
  GalleryEntry('Inputs', 'NumberField', NumberFieldPage.new, reviewed: true),
  GalleryEntry('Inspector', 'PropertyRow', PropertyRowPage.new, reviewed: true),
  GalleryEntry(
    'Inspector',
    'NumberProperty',
    NumberPropertyPage.new,
    reviewed: true,
  ),
  GalleryEntry(
    'Inspector',
    'Vector2Property',
    Vector2PropertyPage.new,
    reviewed: true,
  ),
  GalleryEntry(
    'Inspector',
    'BoolProperty',
    BoolPropertyPage.new,
    reviewed: true,
  ),
  GalleryEntry(
    'Inspector',
    'ColorProperty',
    ColorPropertyPage.new,
    reviewed: true,
  ),
  GalleryEntry('Inspector', 'ColorPicker', ColorPickerPage.new, reviewed: true),
  GalleryEntry('Inspector', 'AssetSlot', AssetSlotPage.new, reviewed: true),
  GalleryEntry('Inspector', 'EntitySlot', EntitySlotPage.new, reviewed: true),
  GalleryEntry('Structure', 'Panel', PanelPage.new, reviewed: true),
  GalleryEntry(
    'Structure',
    'SectionHeader',
    SectionHeaderPage.new,
    reviewed: true,
  ),
  GalleryEntry('Structure', 'Tabs', TabsPage.new, reviewed: true),
  GalleryEntry('Structure', 'TreeRow', TreeRowPage.new, reviewed: true),
  GalleryEntry('Floating', 'ContextMenu', ContextMenuPage.new, reviewed: true),
  GalleryEntry('Floating', 'Tooltip', TooltipPage.new, reviewed: true),
  GalleryEntry('Floating', 'Dialog', DialogPage.new, reviewed: true),
  GalleryEntry('Floating', 'Toast', ToastPage.new, reviewed: true),
  GalleryEntry('Status', 'Badge · DeviceChip', BadgePage.new, reviewed: true),
  GalleryEntry('Status', 'Progress', ProgressPage.new, reviewed: true),
  GalleryEntry('Status', 'Banner', BannerPage.new, reviewed: true),
  GalleryEntry('Status', 'EmptyState', EmptyStatePage.new, reviewed: true),
  GalleryEntry('Shell', 'EditorShell', EditorShellPage.new, reviewed: true),
];

class GalleryApp extends StatelessWidget {
  const GalleryApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'pyro_ui gallery',
    debugShowCheckedModeBanner: false,
    theme: PrTheme.dark(),
    home: const _Gallery(),
  );
}

class _Gallery extends StatefulWidget {
  const _Gallery();

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    String? lastGroup;
    return Scaffold(
      backgroundColor: c.bgApp,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 220,
            color: c.surfacePanel,
            padding: const EdgeInsets.symmetric(vertical: PrSpacing.s2),
            child: PrPanelFocus(
              child: ListView(
                children: [
                  for (final (i, page) in galleryPages.indexed) ...[
                    if (page.group != lastGroup) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                        child: Text(
                          (lastGroup = page.group).toUpperCase(),
                          style: PrText.caption.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                    ],
                    PrTreeRow<Object>(
                      depth: 0,
                      name: page.name,
                      selected: i == _index,
                      badges: [
                        if (page.reviewed)
                          Icon(
                            PrIcons.check,
                            size: PrSizes.iconSm,
                            color: c.success,
                          ),
                      ],
                      onTap: () => setState(() => _index = i),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 1),
          Expanded(
            child: ColoredBox(
              color: c.surfacePanel,
              child: KeyedSubtree(
                key: ValueKey(_index),
                child: galleryPages[_index].build(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
