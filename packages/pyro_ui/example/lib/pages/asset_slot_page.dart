import 'package:flutter/material.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../grid.dart';

PrDropAcceptance _images(String file) {
  if (file.endsWith('.png')) return PrDropAcceptance.accept;
  if (file.endsWith('.wav') || file.endsWith('.ogg')) {
    return PrDropAcceptance.reject;
  }
  return PrDropAcceptance.ignore;
}

PrDropAcceptance _audio(String file) =>
    file.endsWith('.wav') || file.endsWith('.ogg')
    ? PrDropAcceptance.accept
    : PrDropAcceptance.reject;

class AssetSlotPage extends StatefulWidget {
  const AssetSlotPage({super.key});

  @override
  State<AssetSlotPage> createState() => _AssetSlotPageState();
}

class _AssetSlotPageState extends State<AssetSlotPage> {
  final _coin = PrDragInFlight<String>()..value = 'coin.png';
  String? _sprite = 'player_run.png';
  String? _sound;
  String _last = '';

  @override
  void dispose() {
    _coin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    final thumb = ColoredBox(color: c.info);

    Widget row(
      PrAssetSlot<String> slot, {
      String label = 'sprite',
      PrValueSource source = PrValueSource.codeDefault,
    }) => PrPropertyRow(
      label: label,
      source: source,
      onReset: noop,
      resetTooltip: 'Reset to default',
      editor: slot,
    );

    PrAssetSlot<String> sprite({
      String? fileName = 'player_run.png',
      bool missing = false,
      bool mixed = false,
      bool enabled = true,
      PrDragInFlight<String>? inFlight,
    }) => PrAssetSlot<String>(
      fileName: fileName,
      placeholder: 'None (Sprite)',
      thumbnail: missing ? null : thumb,
      typeIcon: missing ? PrIcons.music : PrIcons.image,
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
          'Drag from the Assets panel or Finder. A compatible file shows the '
          'drop-target state under the pointer; a wrong type shows the '
          'reject state there. (An app can also pass a PrDragInFlight to '
          'light up every compatible slot while a drag runs.) Click the name '
          'to reveal the file in Assets; ⌫ clears.',
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
                    source: PrValueSource.overridden,
                  ),
                ]),
              ],
            ),
            const SizedBox(width: PrSpacing.s8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel(
                  'Other asset kinds',
                  detail: 'the thumbnail becomes a type icon',
                ),
                SampleBox(
                  width: 320,
                  child: Column(
                    children: [
                      row(
                        label: 'hurtSound',
                        const PrAssetSlot<String>(
                          fileName: null,
                          placeholder: 'None (AudioSource)',
                          typeIcon: PrIcons.music,
                          onBrowse: noop,
                        ),
                      ),
                      row(
                        label: 'music',
                        const PrAssetSlot<String>(
                          fileName: 'level_theme.ogg',
                          placeholder: 'None (AudioSource)',
                          typeIcon: PrIcons.music,
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
          'Live',
          detail:
              'drag a file onto the slots (the sprite takes .png, the sound '
              '.wav/.ogg)',
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SampleBox(
              width: 360,
              child: PrPropertyList(
                children: [
                  row(
                    PrAssetSlot<String>(
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
                    ),
                  ),
                  row(
                    label: 'hurtSound',
                    PrAssetSlot<String>(
                      fileName: _sound,
                      placeholder: 'None (AudioSource)',
                      typeIcon: PrIcons.music,
                      browseTooltip: 'Browse',
                      clearTooltip: 'Clear',
                      onBrowse: () => setState(() => _last = 'browse sound'),
                      onClear: () => setState(() => _sound = null),
                      willAccept: _audio,
                      onDrop: (f) => setState(() => _sound = f),
                      dropHint: (f) => 'Drop $f here',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: PrSpacing.s6),
            Wrap(
              spacing: PrSpacing.s2,
              children: [
                for (final file in ['coin.png', 'hurt.wav', 'level.json'])
                  Draggable<String>(
                    data: file,
                    dragAnchorStrategy: pointerDragAnchorStrategy,
                    // The drag layer has no text style of its own; without
                    // one, Text falls back to the debug double underline.
                    feedback: DefaultTextStyle(
                      style: PrText.body,
                      child: PrBadge(kind: PrBadgeKind.neutral, label: file),
                    ),
                    child: PrDeviceChip(
                      icon: PrIcons.file,
                      label: file,
                      onPressed: noop,
                    ),
                  ),
              ],
            ),
          ],
        ),
        Text(_last, style: PrText.small.copyWith(color: c.textSecondary)),
      ],
    );
  }
}
