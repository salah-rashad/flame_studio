import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../grid.dart';

PrToastData _reloaded() => const PrToastData(
  kind: PrToastKind.success,
  title: 'Hot reload complete',
  message: '3 libraries reloaded in 412 ms',
);

PrToastData _failed(VoidCallback onAction) => PrToastData(
  kind: PrToastKind.error,
  title: 'Hot reload failed',
  message: "player_controller.dart:42 — The getter 'velocty' isn't defined.",
  actions: [
    PrToastAction(label: 'Show in console', onPressed: onAction),
    PrToastAction(label: 'Restart game', onPressed: onAction),
  ],
);

PrToastData _importing(double? progress) => PrToastData(
  kind: PrToastKind.progress,
  title: 'Importing 24 sprites…',
  dismissible: false,
  progress: progress,
);

PrToastData _missing(VoidCallback onAction) => PrToastData(
  kind: PrToastKind.warning,
  title: '2 nodes reference deleted assets',
  message: 'Fix them before exporting.',
  actions: [PrToastAction(label: 'Review', onPressed: onAction)],
);

class ToastPage extends StatelessWidget {
  const ToastPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget card(PrToastData data) =>
        PrToast(data: data, dismissTooltip: 'Dismiss', onDismiss: noop);

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
          spacing: PrSpacing.s4,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: PrSpacing.s4,
              children: [card(_reloaded()), card(_failed(noop))],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: PrSpacing.s4,
              children: [card(_importing(0.62)), card(_missing(noop))],
            ),
          ],
        ),
        const SectionLabel(
          'Live · an PrToastHost in this box (the app has one above the shell)',
        ),
        Container(
          height: 380,
          constraints: const BoxConstraints(maxWidth: 1000),
          decoration: BoxDecoration(
            color: PrColors.of(context).bgApp,
            border: Border.all(color: PrColors.of(context).borderSubtle),
            borderRadius: PrRadii.sm,
          ),
          clipBehavior: Clip.antiAlias,
          child: const PrToastHost(
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

  void _startImport(PrToastController toasts) {
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
          const PrToastData(
            kind: PrToastKind.success,
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
    final toasts = PrToastHost.of(context);
    return Padding(
      padding: const EdgeInsets.all(PrSpacing.s4),
      child: Align(
        alignment: Alignment.topLeft,
        child: Wrap(
          spacing: PrSpacing.s2,
          runSpacing: PrSpacing.s2,
          children: [
            PrButton(
              label: 'Success',
              onPressed: () => toasts.show(_reloaded()),
            ),
            PrButton(
              label: 'Info',
              onPressed: () => toasts.show(
                PrToastData(
                  kind: PrToastKind.info,
                  title: 'Device connected',
                  message: 'iPhone 15 · ${++_count}',
                ),
              ),
            ),
            PrButton(
              label: 'Warning',
              onPressed: () => toasts.show(_missing(() {})),
            ),
            PrButton(
              label: 'Error',
              onPressed: () => toasts.show(_failed(() {})),
            ),
            PrButton(
              label: 'Import (progress)',
              onPressed: () => _startImport(toasts),
            ),
            PrButton(
              label: 'Show 5 at once',
              onPressed: () {
                for (var i = 1; i <= 5; i++) {
                  toasts.show(
                    PrToastData(kind: PrToastKind.warning, title: 'Warning $i'),
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
