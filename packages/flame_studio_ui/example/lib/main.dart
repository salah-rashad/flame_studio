import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';

import 'pages/foundations_page.dart';
import 'pages/icons_page.dart';
import 'pages/number_property_page.dart';
import 'pages/overlay_page.dart';
import 'pages/property_row_page.dart';
import 'pages/shortcut_label_page.dart';
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

const _pages = <GalleryEntry>[
  GalleryEntry('Foundations', 'Icons', IconsPage.new),
  GalleryEntry('Foundations', 'Field box · Interactive', FoundationsPage.new),
  GalleryEntry('Foundations', 'Anchored overlay', OverlayPage.new),
  GalleryEntry('Foundations', 'Shortcut label', ShortcutLabelPage.new),
  GalleryEntry('Inspector', 'PropertyRow', PropertyRowPage.new),
  GalleryEntry('Inspector', 'NumberProperty', NumberPropertyPage.new),
  GalleryEntry('Inspector', 'Vector2Property', Vector2PropertyPage.new),
  GalleryEntry('Structure', 'TreeRow', TreeRowPage.new),
  GalleryEntry('Floating', 'Tooltip', TooltipPage.new),
];

class GalleryApp extends StatelessWidget {
  const GalleryApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'flame_studio_ui gallery',
    debugShowCheckedModeBanner: false,
    theme: FsTheme.dark(),
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
    final c = FsColors.of(context);
    String? lastGroup;
    return Scaffold(
      backgroundColor: c.bgApp,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 220,
            color: c.surfacePanel,
            padding: const EdgeInsets.symmetric(vertical: FsSpacing.s2),
            child: FsPanelFocus(
              child: ListView(
                children: [
                  for (final (i, page) in _pages.indexed) ...[
                    if (page.group != lastGroup) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                        child: Text(
                          (lastGroup = page.group).toUpperCase(),
                          style: FsText.caption.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                    ],
                    FsTreeRow<Object>(
                      depth: 0,
                      name: page.name,
                      selected: i == _index,
                      badges: [
                        if (page.reviewed)
                          Icon(
                            FsIcons.check,
                            size: FsSizes.iconSm,
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
                child: _pages[_index].build(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
