import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';

import '../grid.dart';

FsDropAcceptance _images(String file) {
  if (file.endsWith('.png')) return FsDropAcceptance.accept;
  if (file.endsWith('.wav') || file.endsWith('.ogg')) {
    return FsDropAcceptance.reject;
  }
  return FsDropAcceptance.ignore;
}

FsDropAcceptance _audio(String file) =>
    file.endsWith('.wav') || file.endsWith('.ogg')
    ? FsDropAcceptance.accept
    : FsDropAcceptance.reject;

class AssetSlotPage extends StatefulWidget {
  const AssetSlotPage({super.key});

  @override
  State<AssetSlotPage> createState() => _AssetSlotPageState();
}

class _AssetSlotPageState extends State<AssetSlotPage> {
  final _inFlight = FsDragInFlight<String>();
  final _coin = FsDragInFlight<String>()..value = 'coin.png';
  String? _sprite = 'player_run.png';
  String? _sound;
  String _last = '';

  @override
  void dispose() {
    _inFlight.dispose();
    _coin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    final thumb = ColoredBox(color: c.info);

    Widget row(
      FsAssetSlot<String> slot, {
      String label = 'sprite',
      FsValueSource source = FsValueSource.codeDefault,
    }) => FsPropertyRow(
      label: label,
      source: source,
      onReset: noop,
      resetTooltip: 'Reset to default',
      editor: slot,
    );

    FsAssetSlot<String> sprite({
      String? fileName = 'player_run.png',
      bool missing = false,
      bool mixed = false,
      bool enabled = true,
      FsDragInFlight<String>? inFlight,
    }) => FsAssetSlot<String>(
      fileName: fileName,
      placeholder: 'None (Sprite)',
      thumbnail: missing ? null : thumb,
      typeIcon: missing ? FsIcons.music : FsIcons.image,
      missing: missing,
      missingLabel: 'Missing',
      mixed: mixed,
      mixedLabel: '— (2 different)',
      browseTooltip: 'Browse',
      clearTooltip: 'Clear',
      onBrowse: noop,
      onClear: noop,
      willAccept: _images,
      onDrop: noop,
      dropHint: (f) => 'Drop $f here',
      dragInFlight: inFlight,
      enabled: enabled,
    );

    return GalleryPage(
      title: 'AssetSlot',
      note:
          'Drag from the Assets panel or Finder. While dragging, every '
          'compatible slot shows the drop-target state (FsDragInFlight); '
          'incompatible slots stay quiet and only show the reject state '
          'under the pointer. Click the name to reveal the file in Assets; '
          '⌫ clears.',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StateGrid(
              columns: const ['AssetSlot'],
              cellWidth: 420,
              labelWidth: 150,
              rows: [
                GridRow('Empty', [row(sprite(fileName: null))]),
                GridRow('Filled', [row(sprite())]),
                GridRow('Hover', [
                  forced(const {WidgetState.hovered}, row(sprite())),
                ]),
                GridRow('Focused', [
                  forced(const {WidgetState.focused}, row(sprite())),
                ]),
                GridRow('Drop target · accepts', [
                  row(sprite(fileName: null, inFlight: _coin)),
                ]),
                GridRow('Drop · wrong type', [
                  forced(
                    const {WidgetState.error},
                    row(sprite()),
                    part: 'drop',
                  ),
                ]),
                GridRow('Missing', [
                  row(sprite(fileName: 'hurt.wav', missing: true)),
                ]),
                GridRow('Disabled', [row(sprite(enabled: false))]),
                GridRow('Mixed', [row(sprite(mixed: true))]),
                GridRow('Overridden', [
                  row(
                    sprite(fileName: 'player_jump.png'),
                    source: FsValueSource.overridden,
                  ),
                ]),
              ],
            ),
            const SizedBox(width: FsSpacing.s8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel(
                  'Other asset kinds: the thumbnail becomes a type icon',
                ),
                SampleBox(
                  width: 320,
                  child: Column(
                    children: [
                      row(
                        label: 'hurtSound',
                        const FsAssetSlot<String>(
                          fileName: null,
                          placeholder: 'None (AudioSource)',
                          typeIcon: FsIcons.music,
                          onBrowse: noop,
                        ),
                      ),
                      row(
                        label: 'music',
                        const FsAssetSlot<String>(
                          fileName: 'level_theme.ogg',
                          placeholder: 'None (AudioSource)',
                          typeIcon: FsIcons.music,
                          onBrowse: noop,
                          onClear: noop,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SectionLabel(
          'Live · drag a file onto the slots (the sprite takes .png, the '
          'sound .wav/.ogg)',
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SampleBox(
              width: 360,
              child: FsPropertyList(
                children: [
                  row(
                    FsAssetSlot<String>(
                      fileName: _sprite,
                      placeholder: 'None (Sprite)',
                      thumbnail: thumb,
                      browseTooltip: 'Browse',
                      clearTooltip: 'Clear',
                      onBrowse: () => setState(() => _last = 'browse sprite'),
                      onClear: () => setState(() => _sprite = null),
                      onReveal: () => setState(() => _last = 'reveal $_sprite'),
                      onOpen: () => setState(() => _last = 'open $_sprite'),
                      willAccept: _images,
                      onDrop: (f) => setState(() => _sprite = f),
                      dropHint: (f) => 'Drop $f here',
                      dragInFlight: _inFlight,
                    ),
                  ),
                  row(
                    label: 'hurtSound',
                    FsAssetSlot<String>(
                      fileName: _sound,
                      placeholder: 'None (AudioSource)',
                      typeIcon: FsIcons.music,
                      browseTooltip: 'Browse',
                      clearTooltip: 'Clear',
                      onBrowse: () => setState(() => _last = 'browse sound'),
                      onClear: () => setState(() => _sound = null),
                      willAccept: _audio,
                      onDrop: (f) => setState(() => _sound = f),
                      dropHint: (f) => 'Drop $f here',
                      dragInFlight: _inFlight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: FsSpacing.s6),
            Wrap(
              spacing: FsSpacing.s2,
              children: [
                for (final file in ['coin.png', 'hurt.wav', 'level.json'])
                  Draggable<String>(
                    data: file,
                    dragAnchorStrategy: pointerDragAnchorStrategy,
                    onDragStarted: () => _inFlight.value = file,
                    onDragEnd: (_) => _inFlight.value = null,
                    feedback: FsBadge(kind: FsBadgeKind.neutral, label: file),
                    child: FsDeviceChip(
                      icon: FsIcons.file,
                      label: file,
                      onPressed: noop,
                    ),
                  ),
              ],
            ),
          ],
        ),
        Text(_last, style: FsText.small.copyWith(color: c.textSecondary)),
      ],
    );
  }
}
