import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';

import '../grid.dart';

class TabsPage extends StatelessWidget {
  const TabsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // One document tab, not selected unless [selected].
    Widget single(
      FsTab<String> tab, {
      Set<WidgetState> states = const {},
      bool selected = false,
    }) => Align(
      alignment: AlignmentDirectional.centerStart,
      child: forced(
        states,
        FsTabs<String>(
          tabs: [tab],
          selected: selected ? tab.value : '',
          onSelect: noop,
          onClose: noop,
          closeTooltip: 'Close',
        ),
      ),
    );
    const level = FsTab(
      value: 'level',
      label: 'level_1.scene',
      icon: FsIcons.file,
    );

    return GalleryPage(
      title: 'Tabs',
      note:
          '28px · label in body, 12px left padding · strip bg-app with 1px '
          'gaps · rest surface-raised + text-secondary · hover surface-hover '
          '· selected surface-panel + text-primary 500 + 2px accent-text top '
          'edge (text-secondary when the panel is unfocused) · dirty: 8px dot '
          'that becomes × on hover · × on hover and on the selected tab · '
          'middle click and ⌘W close.',
      children: [
        Wrap(
          spacing: 40,
          runSpacing: FsSpacing.s6,
          children: [
            StateGrid(
              columns: const ['Document tab'],
              cellWidth: 200,
              labelWidth: 168,
              rows: [
                GridRow('Default', [single(level)]),
                GridRow('Hover', [
                  single(level, states: const {WidgetState.hovered}),
                ]),
                GridRow('Pressed', [
                  single(level, states: const {WidgetState.pressed}),
                ]),
                GridRow('Focused', [
                  single(level, states: const {WidgetState.focused}),
                ]),
                GridRow('Disabled', [
                  single(
                    const FsTab(
                      value: 'level',
                      label: 'level_1.scene',
                      icon: FsIcons.file,
                      enabled: false,
                    ),
                  ),
                ]),
                GridRow('Selected', [single(level, selected: true)]),
                GridRow('Selected · panel unfocused', [
                  FsPanelFocus(child: single(level, selected: true)),
                ]),
                GridRow('Unsaved (dirty)', [
                  single(
                    const FsTab(
                      value: 'menu',
                      label: 'main_menu.scene',
                      icon: FsIcons.file,
                      dirty: true,
                    ),
                  ),
                ]),
                GridRow('Error', [
                  single(
                    const FsTab(
                      value: 'console',
                      label: 'Console',
                      icon: FsIcons.terminal,
                      closable: false,
                      error: true,
                      badges: [FsBadge(kind: FsBadgeKind.error, count: 1)],
                    ),
                  ),
                ]),
              ],
            ),
            SizedBox(
              width: 520,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionLabel('Document tabs'),
                  forced(
                    const {WidgetState.hovered},
                    part: 'main_menu.scene',
                    const _Strip(style: FsTabsStyle.document, tabs: _documents),
                  ),
                  const SizedBox(height: FsSpacing.s4),
                  const SectionLabel('Panel tabs (bottom dock)'),
                  const _Strip(style: FsTabsStyle.dock, tabs: _dock),
                  const SizedBox(height: FsSpacing.s2),
                  Text(
                    'Active tab: surface-panel fill (it merges with the panel '
                    'below) and a 2px accent-text top edge; the edge turns '
                    'text-secondary when the panel loses focus. A dirty tab '
                    'shows a dot that becomes × on hover.',
                    style: FsText.small.copyWith(
                      color: FsColors.of(context).textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SectionLabel(
          'Live: click to select, × or middle click to close, ⌘W closes the '
          'focused strip’s tab; click the panel below the dock to focus it',
        ),
        const _LiveTabs(),
      ],
    );
  }
}

const _documents = [
  FsTab(value: 'level', label: 'level_1.scene', icon: FsIcons.file),
  FsTab(
    value: 'menu',
    label: 'main_menu.scene',
    icon: FsIcons.file,
    dirty: true,
  ),
  FsTab(value: 'player', label: 'player.prefab', icon: FsIcons.box),
];

const _dock = [
  FsTab(
    value: 'console',
    label: 'Console',
    icon: FsIcons.terminal,
    badges: [
      FsBadge(kind: FsBadgeKind.warning, count: 2),
      FsBadge(kind: FsBadgeKind.error, count: 1),
    ],
  ),
  FsTab(value: 'assets', label: 'Assets', icon: FsIcons.folder),
  FsTab(value: 'animation', label: 'Animation', icon: FsIcons.film),
];

/// A static strip with its first tab selected.
class _Strip extends StatelessWidget {
  const _Strip({required this.style, required this.tabs});

  final FsTabsStyle style;
  final List<FsTab<String>> tabs;

  @override
  Widget build(BuildContext context) => FsTabs<String>(
    tabs: tabs,
    selected: tabs.first.value,
    style: style,
    onSelect: noop,
    onClose: noop,
    closeTooltip: 'Close',
  );
}

class _LiveTabs extends StatefulWidget {
  const _LiveTabs();

  @override
  State<_LiveTabs> createState() => _LiveTabsState();
}

class _LiveTabsState extends State<_LiveTabs> {
  final _open = [..._documents];
  String _document = 'level';
  String _dockTab = 'console';

  void _close(String value) => setState(() {
    final i = _open.indexWhere((t) => t.value == value);
    if (i < 0) return;
    _open.removeAt(i);
    if (_document == value && _open.isNotEmpty) {
      _document = _open[i.clamp(0, _open.length - 1)].value;
    }
  });

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    Widget panel(Widget tabs, String text) => FsPanelFocus(
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            tabs,
            GestureDetector(
              onTap: () => FocusScope.of(context).requestFocus(),
              child: Container(
                height: 72,
                color: c.surfacePanel,
                alignment: Alignment.center,
                child: Text(
                  text,
                  style: FsText.small.copyWith(color: c.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return SizedBox(
      width: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          panel(
            FsTabs<String>(
              tabs: _open,
              selected: _document,
              onSelect: (v) => setState(() => _document = v),
              onClose: _close,
              closeTooltip: 'Close',
            ),
            _open.isEmpty
                ? 'All closed — reopen the page'
                : 'Viewport: $_document',
          ),
          const SizedBox(height: 1),
          panel(
            FsTabs<String>(
              tabs: _dock,
              selected: _dockTab,
              style: FsTabsStyle.dock,
              onSelect: (v) => setState(() => _dockTab = v),
            ),
            'Dock: $_dockTab',
          ),
        ],
      ),
    );
  }
}
