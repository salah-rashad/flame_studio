import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';

import '../grid.dart';

FsDropAcceptance _cameras(String node) => node.startsWith('Camera')
    ? FsDropAcceptance.accept
    : FsDropAcceptance.reject;

class EntitySlotPage extends StatefulWidget {
  const EntitySlotPage({super.key});

  @override
  State<EntitySlotPage> createState() => _EntitySlotPageState();
}

class _EntitySlotPageState extends State<EntitySlotPage> {
  final _player = FsDragInFlight<String>()..value = 'Player';
  String? _target = 'Camera';
  bool _picking = false;
  String _last = '';

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);

    Widget row(FsEntitySlot<String> slot) =>
        FsPropertyRow(label: 'target', editor: slot);

    FsEntitySlot<String> target({
      String? name = 'Camera',
      bool picking = false,
      bool missing = false,
      bool mixed = false,
      bool enabled = true,
      FsDragInFlight<String>? inFlight,
    }) => FsEntitySlot<String>(
      name: name,
      placeholder: 'None (CameraComponent)',
      typeIcon: FsIcons.video,
      missing: missing,
      missingLabel: 'Missing',
      mixed: mixed,
      mixedLabel: '— (3 different)',
      picking: picking,
      pickingHint: 'Click a node…',
      pickTooltip: 'Pick in scene',
      clearTooltip: 'Clear',
      onPick: noop,
      onCancelPick: noop,
      onClear: noop,
      // The design's drop example takes any node.
      willAccept: (_) => FsDropAcceptance.accept,
      onDrop: noop,
      dropHint: (n) => 'Drop $n here',
      dragInFlight: inFlight,
      enabled: enabled,
    );

    return GalleryPage(
      title: 'EntitySlot',
      note:
          'Shows the referenced node by name with its type icon. Accepts '
          'drags from the scene tree. The crosshair starts pick mode: the '
          'viewport and tree highlight valid targets, Esc cancels. Missing = '
          'the referenced node was deleted or renamed out of the scene; the '
          'old name stays visible so the user knows what to re-link.',
      children: [
        StateGrid(
          columns: const ['EntitySlot'],
          cellWidth: 420,
          labelWidth: 150,
          rows: [
            GridRow('Empty', [row(target(name: null))]),
            GridRow('Filled', [row(target())]),
            GridRow('Hover', [
              forced(const {WidgetState.hovered}, row(target())),
            ]),
            GridRow('Focused', [
              forced(const {WidgetState.focused}, row(target())),
            ]),
            GridRow('Picking in viewport', [
              row(target(name: null, picking: true)),
            ]),
            GridRow('Drop target · accepts', [
              row(target(name: null, inFlight: _player)),
            ]),
            GridRow('Drop · wrong type', [
              forced(const {WidgetState.error}, row(target()), part: 'drop'),
            ]),
            GridRow('Missing', [row(target(name: 'Enemy#42', missing: true))]),
            GridRow('Disabled', [row(target(enabled: false))]),
            GridRow('Mixed', [row(target(mixed: true))]),
          ],
        ),
        const SectionLabel(
          'Live · the crosshair toggles pick mode (click "Camera2" to pick '
          'it); or drag a node (only cameras fit)',
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SampleBox(
              width: 360,
              child: row(
                FsEntitySlot<String>(
                  name: _target,
                  placeholder: 'None (CameraComponent)',
                  typeIcon: FsIcons.video,
                  picking: _picking,
                  pickingHint: 'Click a node in the scene…',
                  pickTooltip: 'Pick in scene',
                  clearTooltip: 'Clear',
                  onPick: () => setState(() => _picking = true),
                  onCancelPick: () => setState(() => _picking = false),
                  onClear: () => setState(() => _target = null),
                  onReveal: () => setState(() => _last = 'reveal $_target'),
                  willAccept: _cameras,
                  onDrop: (n) => setState(() => _target = n),
                  dropHint: (n) => 'Drop $n here',
                ),
              ),
            ),
            const SizedBox(width: FsSpacing.s6),
            SizedBox(
              width: 200,
              child: FsPanelFocus(
                child: Column(
                  children: [
                    for (final (node, icon) in [
                      ('Camera2', FsIcons.video),
                      ('Player', FsIcons.image),
                    ])
                      FsTreeRow<String>(
                        depth: 0,
                        name: node,
                        icon: icon,
                        dragData: node,
                        onTap: _picking && node.startsWith('Camera')
                            ? () => setState(() {
                                _target = node;
                                _picking = false;
                              })
                            : null,
                        dragFeedback: () =>
                            FsBadge(kind: FsBadgeKind.neutral, label: node),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Text(_last, style: FsText.small.copyWith(color: c.textSecondary)),
      ],
    );
  }
}
