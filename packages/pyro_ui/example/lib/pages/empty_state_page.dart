import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../grid.dart';

class EmptyStatePage extends StatefulWidget {
  const EmptyStatePage({super.key});

  @override
  State<EmptyStatePage> createState() => _EmptyStatePageState();
}

class _EmptyStatePageState extends State<EmptyStatePage> {
  String _query = 'slme';

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    Widget box(double width, Widget child, {bool viewport = false}) =>
        Container(
          width: width,
          height: 260,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: viewport ? c.bgViewport : c.surfacePanel,
            border: Border.all(color: c.borderSubtle),
            borderRadius: PrRadii.sm,
          ),
          child: child,
        );
    final newScene = PrShortcutLabel.describe(
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true),
    );

    return GalleryPage(
      title: 'EmptyState',
      note:
          'Centred: a 48px tile with the panel\'s icon, a title, one line '
          '(max 280px) and one button. Primary for the action that fills '
          'the panel, secondary for recovery. No illustrations.',
      children: [
        Wrap(
          spacing: PrSpacing.s4,
          runSpacing: PrSpacing.s4,
          children: [
            box(
              420,
              viewport: true,
              PrEmptyState(
                icon: PrIcons.layers,
                title: 'No scene open',
                message:
                    'Open a scene from Assets, or start a new one from a '
                    'template.',
                action: PrButton(
                  label: 'New scene',
                  icon: PrIcons.plus,
                  variant: PrButtonVariant.primary,
                  onPressed: () {},
                ),
                shortcutHint: 'or press $newScene',
              ),
            ),
            box(
              300,
              PrEmptyState(
                icon: PrIcons.terminal,
                title: 'No output yet',
                message:
                    'Logs, warnings and errors from your game appear here.',
                action: PrButton(
                  label: 'Run game',
                  leading: const PrPlayGlyph(size: 14),
                  variant: PrButtonVariant.primary,
                  onPressed: () {},
                ),
              ),
            ),
            box(
              300,
              PrEmptyState(
                icon: PrIcons.search,
                title: 'No nodes match “slme”',
                message:
                    'Check the spelling or search by component type, e.g. '
                    't:SpriteComponent.',
                action: PrButton(label: 'Clear search', onPressed: () {}),
              ),
            ),
          ],
        ),
        const SectionLabel(
          'Live',
          detail: 'search a list; clear it from the empty state',
        ),
        Builder(
          builder: (context) {
            const nodes = ['Player', 'Slime', 'Camera', 'Tilemap'];
            final hits = [
              for (final n in nodes)
                if (n.toLowerCase().contains(_query.toLowerCase())) n,
            ];
            return SizedBox(
              width: 300,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: PrSpacing.s2,
                children: [
                  PrSearchField(
                    query: _query,
                    placeholder: 'Search',
                    clearTooltip: 'Clear',
                    noMatch: hits.isEmpty,
                    onChanged: (q) => setState(() => _query = q),
                  ),
                  box(
                    300,
                    hits.isEmpty
                        ? PrEmptyState(
                            icon: PrIcons.search,
                            title: 'No nodes match “$_query”',
                            message: 'Check the spelling.',
                            action: PrButton(
                              label: 'Clear search',
                              onPressed: () => setState(() => _query = ''),
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final n in hits)
                                Text(
                                  n,
                                  style: PrText.body.copyWith(
                                    color: c.textPrimary,
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
