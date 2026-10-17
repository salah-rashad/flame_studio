import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../grid.dart';

const _find = SingleActivator(LogicalKeyboardKey.keyF, meta: true);

const _nodes = [
  'Player',
  'SlimeA',
  'SlimeB',
  'Bat',
  'Coin',
  'SlimeKing',
  'Camera',
  'Ground',
  'Spikes',
  'Door',
  'Torch',
  'HUD',
];

class SearchFieldPage extends StatefulWidget {
  const SearchFieldPage({super.key});

  @override
  State<SearchFieldPage> createState() => _SearchFieldPageState();
}

class _SearchFieldPageState extends State<SearchFieldPage> {
  final _list = FocusNode(debugLabel: 'node list');
  String _query = '';
  int _current = 0;

  @override
  void dispose() {
    _list.dispose();
    super.dispose();
  }

  List<String> get _matches => [
    for (final n in _nodes)
      if (n.toLowerCase().contains(_query.toLowerCase())) n,
  ];

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);

    Widget cell(
      String query, {
      Set<WidgetState> states = const {},
      bool enabled = true,
      bool noMatch = false,
    }) {
      final field = FsSearchField(
        query: query,
        placeholder: 'Search nodes',
        resultLabel: '3 of 12',
        noMatch: noMatch,
        noMatchLabel: 'No match',
        shortcutHint: _find,
        enabled: enabled,
        onChanged: noop,
      );
      return Padding(
        padding: const EdgeInsets.all(FsSpacing.s2),
        child: states.isEmpty ? field : forced(states, field, part: 'field'),
      );
    }

    GridRow row(
      String name, {
      Set<WidgetState> states = const {},
      bool enabled = true,
      bool noMatch = false,
    }) => GridRow(name, [
      cell('', states: states, enabled: enabled),
      cell('slime', states: states, enabled: enabled, noMatch: noMatch),
    ]);

    final matches = _matches;
    final current = matches.isEmpty
        ? null
        : matches[_current.clamp(0, matches.length - 1)];

    return GalleryPage(
      title: 'SearchField',
      note:
          'Filters as you type (no Enter). Esc clears, a second Esc returns '
          'focus to the list. ↑/↓ move through results without leaving the '
          'field.',
      children: [
        StateGrid(
          columns: const ['Empty', 'With query'],
          cellWidth: 240,
          labelWidth: 88,
          rows: [
            row('Default'),
            row('Hover', states: {WidgetState.hovered}),
            row('Focused', states: {WidgetState.focused}),
            row('Disabled', enabled: false),
            row('No results', noMatch: true),
          ],
        ),
        const SectionLabel('Live'),
        SizedBox(
          width: 240,
          child: FsSearchField(
            query: _query,
            placeholder: 'Search nodes',
            shortcutHint: _find,
            clearTooltip: 'Clear',
            resultLabel: matches.isEmpty
                ? null
                : '${_current.clamp(0, matches.length - 1) + 1} of '
                      '${matches.length}',
            noMatch: matches.isEmpty,
            noMatchLabel: 'No match',
            onChanged: (q) => setState(() {
              _query = q;
              _current = 0;
            }),
            onNext: () => setState(
              () => _current = (_current + 1) % matches.length.clamp(1, 99),
            ),
            onPrevious: () => setState(
              () => _current =
                  (_current - 1 + matches.length) % matches.length.clamp(1, 99),
            ),
            onExit: _list.requestFocus,
          ),
        ),
        Focus(
          focusNode: _list,
          child: ListenableBuilder(
            listenable: _list,
            builder: (context, _) => SizedBox(
              width: 240,
              child: FsPanelFocus(
                child: Column(
                  children: [
                    for (final n in matches)
                      FsTreeRow<Object>(
                        depth: 0,
                        name: n,
                        icon: FsIcons.circleDot,
                        selected: n == current,
                      ),
                    if (matches.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(FsSpacing.s2),
                        child: Text(
                          'No nodes match "$_query".',
                          style: FsText.small.copyWith(color: c.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
