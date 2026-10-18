import 'dart:async';

import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';

import '../grid.dart';

FsToastData _reloaded() => const FsToastData(
  kind: FsToastKind.success,
  title: 'Hot reload complete',
  message: '3 libraries reloaded in 412 ms',
);

FsToastData _failed(VoidCallback onAction) => FsToastData(
  kind: FsToastKind.error,
  title: 'Hot reload failed',
  message: "player_controller.dart:42 — The getter 'velocty' isn't defined.",
  actions: [
    FsToastAction(label: 'Show in console', onPressed: onAction),
    FsToastAction(label: 'Restart game', onPressed: onAction),
  ],
);

FsToastData _importing(double? progress) => FsToastData(
  kind: FsToastKind.progress,
  title: 'Importing 24 sprites…',
  dismissible: false,
  progress: progress,
);

FsToastData _missing(VoidCallback onAction) => FsToastData(
  kind: FsToastKind.warning,
  title: '2 nodes reference deleted assets',
  message: 'Fix them before exporting.',
  actions: [FsToastAction(label: 'Review', onPressed: onAction)],
);

class ToastPage extends StatelessWidget {
  const ToastPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget card(FsToastData data) =>
        FsToast(data: data, dismissTooltip: 'Dismiss', onDismiss: noop);

    return GalleryPage(
      title: 'Toast',
      note:
          'Bottom-right of the window, 16px from the edges, stacked newest on '
          'top, max 3. Success/info dismiss after 4s (paused on hover); '
          'errors and warnings stay until dismissed. Never the only place an '
          'error is reported — the console has it too.',
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: FsSpacing.s4,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: FsSpacing.s4,
              children: [card(_reloaded()), card(_failed(noop))],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: FsSpacing.s4,
              children: [card(_importing(0.62)), card(_missing(noop))],
            ),
          ],
        ),
        const SectionLabel(
          'Live · an FsToastHost in this box (the app has one above the shell)',
        ),
        Container(
          height: 380,
          constraints: const BoxConstraints(maxWidth: 1000),
          decoration: BoxDecoration(
            color: FsColors.of(context).bgApp,
            border: Border.all(color: FsColors.of(context).borderSubtle),
            borderRadius: FsRadii.sm,
          ),
          clipBehavior: Clip.antiAlias,
          child: const FsToastHost(
            dismissTooltip: 'Dismiss',
            child: _LiveControls(),
          ),
        ),
      ],
    );
  }
}

class _LiveControls extends StatefulWidget {
  const _LiveControls();

  @override
  State<_LiveControls> createState() => _LiveControlsState();
}

class _LiveControlsState extends State<_LiveControls> {
  Timer? _import;
  int _count = 0;

  @override
  void dispose() {
    _import?.cancel();
    super.dispose();
  }

  void _startImport(FsToastController toasts) {
    _import?.cancel();
    final handle = toasts.show(_importing(null));
    var done = 0;
    // Indeterminate first, then 24 steps, then a success.
    _import = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      done++;
      if (done <= 6) return;
      final progress = (done - 6) / 24;
      if (progress >= 1) {
        timer.cancel();
        handle.update(
          const FsToastData(
            kind: FsToastKind.success,
            title: 'Imported 24 sprites',
            message: 'assets/sprites/player',
          ),
        );
      } else {
        handle.update(_importing(progress));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final toasts = FsToastHost.of(context);
    return Padding(
      padding: const EdgeInsets.all(FsSpacing.s4),
      child: Align(
        alignment: Alignment.topLeft,
        child: Wrap(
          spacing: FsSpacing.s2,
          runSpacing: FsSpacing.s2,
          children: [
            FsButton(
              label: 'Success',
              onPressed: () => toasts.show(_reloaded()),
            ),
            FsButton(
              label: 'Info',
              onPressed: () => toasts.show(
                FsToastData(
                  kind: FsToastKind.info,
                  title: 'Device connected',
                  message: 'iPhone 15 · ${++_count}',
                ),
              ),
            ),
            FsButton(
              label: 'Warning',
              onPressed: () => toasts.show(_missing(() {})),
            ),
            FsButton(
              label: 'Error',
              onPressed: () => toasts.show(_failed(() {})),
            ),
            FsButton(
              label: 'Import (progress)',
              onPressed: () => _startImport(toasts),
            ),
            FsButton(
              label: 'Show 5 at once',
              onPressed: () {
                for (var i = 1; i <= 5; i++) {
                  toasts.show(
                    FsToastData(kind: FsToastKind.warning, title: 'Warning $i'),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
