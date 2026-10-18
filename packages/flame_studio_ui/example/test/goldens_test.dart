@Tags(['golden'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flame_studio_ui_gallery/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// One golden per gallery page (plan §6.2): the automatic check that a
/// component still looks like its preview.html after a token or layout
/// change. macOS only, since font rasterisation differs between platforms.
///
/// Refresh deliberately: `flutter test --tags golden --update-goldens`.
void main() {
  setUpAll(() {
    final local = goldenFileComparator as LocalFileComparator;
    goldenFileComparator = _TolerantComparator(
      Uri.parse('${local.basedir}goldens_test.dart'),
    );
  });

  for (final page in galleryPages) {
    testWidgets('golden: ${page.name}', (tester) async {
      // The page's width in the gallery at 1440×900 (the sidebar takes
      // 221px); the height grows to fit a scrolling page.
      const width = 1219.0;
      var height = 900.0;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      Future<void> pumpPage() async {
        tester.view.physicalSize = Size(width, height);
        await tester.pumpWidget(
          // The boundary wraps the whole app, so layers in the app's Overlay
          // (an open dropdown list, a menu) are part of the golden.
          RepaintBoundary(
            key: const Key('page'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: FsTheme.dark(),
              home: Material(
                color: FsColors.dark.surfacePanel,
                child: page.build(),
              ),
            ),
          ),
        );
        // Fixed pumps, not pumpAndSettle: some pages show endless
        // indeterminate animations.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      await pumpPage();
      final scrollables = find.byType(Scrollable);
      if (scrollables.evaluate().isNotEmpty) {
        final position = tester
            .state<ScrollableState>(scrollables.first)
            .position;
        if (position.axis == Axis.vertical && position.maxScrollExtent > 0) {
          height += position.maxScrollExtent;
          await pumpPage();
        }
      }

      await expectLater(
        find.byKey(const Key('page')),
        matchesGoldenFile('goldens/${_slug(page.name)}.png'),
      );
      // Let page timers and fades end before the next page.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    }, skip: !Platform.isMacOS);
  }
}

String _slug(String name) => name
    .toLowerCase()
    .replaceAll(RegExp('[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_|_$'), '');

/// Allows a sliver of differing pixels, so anti-aliasing differences
/// between Mac machines (Intel and Apple silicon) don't fail the build; a
/// real change moves far more than this.
class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  /// The largest share of pixels that may differ.
  static const double tolerance = 0.002;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= tolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
