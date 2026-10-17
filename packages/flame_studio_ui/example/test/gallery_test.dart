import 'package:flame_studio_ui_gallery/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in const [Size(1440, 900), Size(1280, 800)]) {
    testWidgets('every page builds without errors at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const GalleryApp());
      await tester.pump();
      for (final name in const [
        'Icons',
        'Field box · Interactive',
        'Anchored overlay',
        'Shortcut label',
        'Button',
        'IconButton',
        'ToggleButton',
        'SegmentedControl',
        'SplitButton',
        'Toolbar',
        'TextField',
        'Dropdown',
        'SearchField',
        'NumberField',
        'PropertyRow',
        'NumberProperty',
        'Vector2Property',
        'BoolProperty',
        'ColorProperty',
        'ColorPicker',
        'AssetSlot',
        'EntitySlot',
        'Panel',
        'SectionHeader',
        'Tabs',
        'TreeRow',
        'ContextMenu',
        'Tooltip',
        'Dialog',
        'Toast',
        'Badge · DeviceChip',
        'Progress',
      ]) {
        // The sidebar is longer than the window: scroll the entry in.
        await tester.scrollUntilVisible(
          find.text(name).first,
          40,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text(name).first);
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull, reason: name);
      }
    });
  }
}
