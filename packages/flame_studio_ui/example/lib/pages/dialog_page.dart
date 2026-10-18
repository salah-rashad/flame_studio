import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';

import '../grid.dart';

/// The unsaved-changes dialog from preview.html.
FsDialog<String> _saveDialog({
  bool? alwaysSave,
  ValueChanged<bool>? onAlways,
}) => FsDialog(
  title: 'Save changes to level_1.scene?',
  body:
      'You have 3 unsaved changes. If you close the scene without saving, '
      'they will be lost.',
  content: _AlwaysSave(value: alwaysSave ?? false, onChanged: onAlways),
  primary: const FsDialogAction(label: 'Save', value: 'Save'),
  secondary: const FsDialogAction(label: 'Cancel', value: 'Cancel'),
  destructive: const FsDialogAction(label: "Don't save", value: "Don't save"),
  closeTooltip: 'Close',
);

class _AlwaysSave extends StatefulWidget {
  const _AlwaysSave({required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  State<_AlwaysSave> createState() => _AlwaysSaveState();
}

class _AlwaysSaveState extends State<_AlwaysSave> {
  late bool _value = widget.value;

  @override
  Widget build(BuildContext context) => Row(
    spacing: FsSpacing.s2,
    children: [
      FsCheckbox(
        value: _value,
        semanticsLabel: 'Always save when closing scenes',
        onChanged: (v) {
          setState(() => _value = v);
          widget.onChanged?.call(v);
        },
      ),
      const Text('Always save when closing scenes'),
    ],
  );
}

class DialogPage extends StatefulWidget {
  const DialogPage({super.key});

  @override
  State<DialogPage> createState() => _DialogPageState();
}

class _DialogPageState extends State<DialogPage> {
  String _answer = '—';
  bool _alwaysSave = false;

  Future<void> _ask(
    FsDialog<String> dialog, {
    bool barrierDismissible = false,
  }) async {
    final answer = await showFsDialog(
      context,
      dialog: dialog,
      barrierDismissible: barrierDismissible,
    );
    if (mounted) setState(() => _answer = answer ?? 'null (Esc / ×)');
  }

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    final sample = Container(
      height: 300,
      decoration: BoxDecoration(color: c.bgApp, borderRadius: FsRadii.sm),
      clipBehavior: Clip.antiAlias,
      child: ColoredBox(
        color: c.scrim,
        child: Center(
          // Inline: no route, so the buttons do nothing and nothing takes
          // focus.
          child: ExcludeFocus(
            child: forced(
              const {WidgetState.focused},
              _saveDialog(),
              part: 'primary',
            ),
          ),
        ),
      ),
    );

    final form = FsDialog<String>(
      title: 'New scene',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: FsSpacing.s1,
        children: [
          Text('Name', style: FsText.small.copyWith(color: c.textSecondary)),
          const FsTextField(
            value: 'level_2',
            autofocus: true,
            selectAllOnFocus: true,
          ),
        ],
      ),
      primary: const FsDialogAction(label: 'Create', value: 'Create'),
      secondary: const FsDialogAction(label: 'Cancel', value: 'Cancel'),
      width: FsDialogWidth.form,
      closeTooltip: 'Close',
    );

    return GalleryPage(
      title: 'Dialog',
      note:
          '440px wide (560 for forms). Title is a question or an action; '
          'buttons are verbs. The primary button holds initial focus and '
          'answers Enter; Esc = Cancel. Destructive choice sits apart on the '
          'left. Focus is trapped until the dialog closes.',
      children: [
        const SectionLabel('Unsaved changes · primary focused'),
        sample,
        const SectionLabel('Live · showFsDialog (200ms fade over the scrim)'),
        Row(
          spacing: FsSpacing.s2,
          children: [
            FsButton(
              label: 'Close scene…',
              onPressed: () => _ask(
                _saveDialog(
                  alwaysSave: _alwaysSave,
                  onAlways: (v) => _alwaysSave = v,
                ),
              ),
            ),
            FsButton(
              label: 'New scene… (scrim closes)',
              onPressed: () => _ask(form, barrierDismissible: true),
            ),
            const SizedBox(width: FsSpacing.s2),
            Text(
              'Answer: $_answer',
              style: FsText.small.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}
