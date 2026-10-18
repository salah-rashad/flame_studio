import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_ui/pyro_ui.dart';
import 'package:pyro_ui/src/foundation/focus_ring.dart';

import '../helpers.dart';

final _header = find.byType(PrSectionHeader);

Color? _fill(WidgetTester tester) => decorationIn(tester, _header).color;

Color? _iconColor(WidgetTester tester, IconData icon) =>
    tester.widget<Icon>(find.byIcon(icon)).color;

Future<void> _click(WidgetTester tester, Offset at) async {
  final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await g.addPointer(location: at);
  await g.down(at);
  await g.up();
  await g.removePointer();
  await tester.pumpAndSettle();
}

/// The text style of the span showing [text] in the header's rich text.
TextStyle? _spanStyle(WidgetTester tester, String text) {
  final rich = tester.widget<RichText>(
    find
        .descendant(
          of: _header,
          matching: find.byWidgetPredicate(
            (w) =>
                w is RichText &&
                w.text.toPlainText().contains('SpriteComponent'),
          ),
        )
        .first,
  );
  TextStyle? found;
  rich.text.visitChildren((span) {
    if (span is TextSpan && span.text == text) {
      found = span.style;
      return false;
    }
    return true;
  });
  return found;
}

class _Harness extends StatefulWidget {
  const _Harness({
    this.enabled,
    this.subtitle,
    this.error = false,
    this.onToggleAll,
    this.menu = const [],
    this.actions = const [],
    this.log,
  });

  final bool? enabled;
  final String? subtitle;
  final bool error;
  final VoidCallback? onToggleAll;
  final List<PrMenuEntry<void>> menu;
  final List<Widget> actions;
  final List<String>? log;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool expanded = true;
  late bool? enabled = widget.enabled;

  @override
  Widget build(BuildContext context) => PrSectionHeader(
    title: 'SpriteComponent',
    icon: PrIcons.film,
    subtitle: widget.subtitle,
    expanded: expanded,
    onExpandedChanged: (v) {
      widget.log?.add('expanded $v');
      setState(() => expanded = v);
    },
    onToggleAll: widget.onToggleAll,
    enabled: enabled,
    onEnabledChanged: (v) {
      widget.log?.add('enabled $v');
      setState(() => enabled = v);
    },
    actions: widget.actions,
    menu: widget.menu,
    menuTooltip: 'More',
    error: widget.error,
  );
}

void main() {
  group('look', () {
    testWidgets('24px raised; bg-app top and border-subtle bottom edges', (
      tester,
    ) async {
      await pumpFs(tester, const _Harness());
      expect(tester.getSize(_header).height, 24);
      final d = decorationIn(tester, _header);
      expect(d.color, c.surfaceRaised);
      final border = d.border! as Border;
      expect(border.top.color, c.bgApp);
      expect(border.bottom.color, c.borderSubtle);
    });

    testWidgets('expanded: chevron down; collapsed: chevron right', (
      tester,
    ) async {
      await pumpFs(tester, const _Harness());
      expect(find.byIcon(PrIcons.chevronDown), findsOneWidget);
      await _click(tester, tester.getCenter(_header));
      expect(find.byIcon(PrIcons.chevronRight), findsOneWidget);
      expect(_iconColor(tester, PrIcons.chevronRight), c.textSecondary);
    });

    testWidgets('title in section, primary; subtitle after a dash', (
      tester,
    ) async {
      await pumpFs(tester, const _Harness(subtitle: 'player.png'));
      final title = _spanStyle(tester, 'SpriteComponent')!;
      expect(title.fontSize, PrText.section.fontSize);
      expect(title.fontWeight, PrText.section.fontWeight);
      expect(title.color, c.textPrimary);
      final subtitle = _spanStyle(tester, ' — player.png')!;
      expect(subtitle.color, c.textSecondary);
      expect(subtitle.fontWeight, PrText.small.fontWeight);
      expect(_iconColor(tester, PrIcons.film), c.textPrimary);
    });

    testWidgets('hover and pressed fills', (tester) async {
      await pumpFs(
        tester,
        const PrDebugStates(states: {WidgetState.hovered}, child: _Harness()),
      );
      expect(_fill(tester), c.surfaceHover);
      await pumpFs(
        tester,
        const PrDebugStates(states: {WidgetState.pressed}, child: _Harness()),
      );
      expect(_fill(tester), c.surfacePressed);
    });

    testWidgets('forced states reach the header, not its checkbox', (
      tester,
    ) async {
      await pumpFs(
        tester,
        const PrDebugStates(
          states: {WidgetState.pressed},
          child: _Harness(enabled: true),
        ),
      );
      final box = decorationIn(tester, find.byType(PrCheckbox));
      expect(box.color, c.accent);
    });

    testWidgets('keyboard focus: inset ring', (tester) async {
      await pumpFs(tester, const _Harness());
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final ring = tester.widget<PrFocusRing>(
        find.descendant(of: _header, matching: find.byType(PrFocusRing)).first,
      );
      expect(ring.visible, isTrue);
      expect(hasPainter<PrEdgePainter>(tester, _header), isTrue);
    });

    testWidgets('disabled component: chevron, icon and title disabled', (
      tester,
    ) async {
      await pumpFs(tester, const _Harness(enabled: false, subtitle: 'off'));
      expect(_spanStyle(tester, 'SpriteComponent')!.color, c.textDisabled);
      expect(_iconColor(tester, PrIcons.film), c.textDisabled);
      expect(_iconColor(tester, PrIcons.chevronDown), c.textDisabled);
      expect(tester.widget<PrCheckbox>(find.byType(PrCheckbox)).value, false);
    });

    testWidgets('error: the icon becomes the alert circle in error', (
      tester,
    ) async {
      await pumpFs(
        tester,
        const _Harness(error: true, subtitle: 'compile error'),
      );
      expect(find.byIcon(PrIcons.film), findsNothing);
      expect(_iconColor(tester, PrIcons.alertCircle), c.error);
      expect(_spanStyle(tester, 'SpriteComponent')!.color, c.textPrimary);
    });

    testWidgets('no checkbox when enabled is null', (tester) async {
      await pumpFs(tester, const _Harness());
      expect(find.byType(PrCheckbox), findsNothing);
    });
  });

  group('input', () {
    testWidgets('click toggles expanded', (tester) async {
      final log = <String>[];
      await pumpFs(tester, _Harness(log: log));
      await _click(tester, tester.getCenter(_header));
      await _click(tester, tester.getCenter(_header));
      expect(log, ['expanded false', 'expanded true']);
    });

    testWidgets('Space and Enter toggle while focused', (tester) async {
      final log = <String>[];
      await pumpFs(tester, _Harness(log: log));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(log, ['expanded false', 'expanded true']);
    });

    testWidgets('Alt-click calls onToggleAll instead', (tester) async {
      final log = <String>[];
      await pumpFs(
        tester,
        _Harness(log: log, onToggleAll: () => log.add('all')),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await _click(tester, tester.getCenter(_header));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      expect(log, ['all']);
    });

    testWidgets('Alt-click without onToggleAll is a plain click', (
      tester,
    ) async {
      final log = <String>[];
      await pumpFs(tester, _Harness(log: log));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await _click(tester, tester.getCenter(_header));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      expect(log, ['expanded false']);
    });

    testWidgets('the checkbox changes enabled without toggling', (
      tester,
    ) async {
      final log = <String>[];
      await pumpFs(tester, _Harness(enabled: true, log: log));
      await _click(tester, tester.getCenter(find.byType(PrCheckbox)));
      expect(log, ['enabled false']);
      expect(_spanStyle(tester, 'SpriteComponent')!.color, c.textDisabled);
      await _click(tester, tester.getCenter(find.byType(PrCheckbox)));
      expect(log, ['enabled false', 'enabled true']);
    });

    testWidgets('actions and the ⋯ menu work without toggling', (tester) async {
      final log = <String>[];
      await pumpFs(
        tester,
        _Harness(
          log: log,
          actions: [
            PrIconButton(
              icon: PrIcons.info,
              tooltip: 'Help',
              size: PrIconButtonSize.small,
              onPressed: () => log.add('help'),
            ),
          ],
          menu: [
            PrMenuItem(label: 'Reset', onSelected: () => log.add('reset')),
          ],
        ),
      );
      await _click(tester, tester.getCenter(find.byIcon(PrIcons.info)));
      await _click(tester, tester.getCenter(find.byIcon(PrIcons.more)));
      expect(find.text('Reset'), findsOneWidget);
      await _click(tester, tester.getCenter(find.text('Reset')));
      expect(log, ['help', 'reset']);
      expect(tester.getRect(find.byIcon(PrIcons.more)).right, 360 - 4);
    });
  });

  group('PrCollapsible', () {
    Widget collapsible(bool expanded) => PrCollapsible(
      expanded: expanded,
      child: const SizedBox(height: 100, child: Text('body')),
    );

    testWidgets('animates the height over 150ms', (tester) async {
      await pumpFs(tester, collapsible(true));
      final box = find.byType(PrCollapsible);
      expect(tester.getSize(box).height, 100);

      await pumpFs(tester, collapsible(false));
      await tester.pump(const Duration(milliseconds: 75));
      final mid = tester.getSize(box).height;
      expect(mid, greaterThan(0));
      expect(mid, lessThan(100));
      await tester.pumpAndSettle();
      expect(tester.getSize(box).height, 0);

      await pumpFs(tester, collapsible(true));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(tester.getSize(box).height, 100);
    });

    testWidgets('closed: keeps its state but hides and skips focus', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      Widget build(bool expanded) => PrCollapsible(
        expanded: expanded,
        child: Focus(focusNode: node, child: const Text('body')),
      );
      await pumpFs(tester, build(false));
      expect(find.text('body'), findsNothing); // offstage
      expect(find.text('body', skipOffstage: false), findsOneWidget);
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isFalse);

      await pumpFs(tester, build(true));
      await tester.pumpAndSettle();
      expect(find.text('body'), findsOneWidget);
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isTrue);
    });
  });
}
