import 'dart:async';

import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';

import '../grid.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  bool _busy = false;
  Timer? _work;

  @override
  void dispose() {
    _work?.cancel();
    super.dispose();
  }

  /// Runs fake work for [length]: quick work never shows progress.
  void _run(Duration length) {
    _work?.cancel();
    setState(() => _busy = true);
    _work = Timer(length, () => setState(() => _busy = false));
  }

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);

    Widget column(double? width, List<Widget> children) => SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: FsSpacing.s2,
        children: children,
      ),
    );

    Widget labelled(Widget indicator, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        indicator,
        Text(label, style: FsText.small.copyWith(color: c.textSecondary)),
      ],
    );

    Widget panel({required bool reduceMotion}) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: Container(
        height: FsPanel.headerHeight + 40 + 2,
        decoration: BoxDecoration(
          border: Border.all(color: c.borderSubtle),
          borderRadius: FsRadii.sm,
        ),
        clipBehavior: Clip.antiAlias,
        child: FsPanel(
          title: 'Assets',
          icon: FsIcons.folder,
          headerProgress: const FsProgressBar(),
          body: const SizedBox.shrink(),
        ),
      ),
    );

    final sheet = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 40,
      children: [
        column(280, [
          const SectionLabel('Indeterminate bar · 2px · under a panel header'),
          panel(reduceMotion: false),
          const SizedBox(height: FsSpacing.s1),
          const SectionLabel('Determinate'),
          const FsProgressBar(value: 0.62),
          const SizedBox(height: FsSpacing.s1),
          const SectionLabel('Background (info) · determinate'),
          const FsProgressBar(value: 0.62, tone: FsProgressTone.background),
        ]),
        column(null, [
          const SectionLabel('Spinner · 14 / 16'),
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: FsSpacing.s3,
            children: [
              const FsSpinner(),
              const FsSpinner(size: 16),
              labelled(const FsSpinner(), 'Building…'),
            ],
          ),
        ]),
        column(null, const [
          SectionLabel('Status dot · always with a label'),
          FsStatusDot(status: FsStatus.idle, label: 'Idle'),
          FsStatusDot(status: FsStatus.working, label: 'Hot reloading…'),
          FsStatusDot(status: FsStatus.ok, label: 'Running · 60 fps'),
          FsStatusDot(status: FsStatus.error, label: 'Crashed — see console'),
        ]),
      ],
    );

    final reduced = MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 40,
        children: [
          SizedBox(width: 280, child: panel(reduceMotion: true)),
          const FsSpinner(),
          const FsStatusDot(status: FsStatus.working, label: 'Hot reloading…'),
        ],
      ),
    );

    final live = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 40,
      children: [
        column(280, [
          Row(
            spacing: FsSpacing.s2,
            children: [
              FsButton(
                label: 'Quick task (200ms)',
                onPressed: () => _run(const Duration(milliseconds: 200)),
              ),
              FsButton(
                label: 'Long task (2s)',
                onPressed: () => _run(const Duration(seconds: 2)),
              ),
            ],
          ),
          SizedBox(
            height: FsProgressBar.height,
            child: FsDelayedProgress(busy: _busy, child: const FsProgressBar()),
          ),
        ]),
        column(null, [
          SizedBox(
            height: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                FsDelayedProgress(busy: _busy, child: const FsSpinner()),
                FsStatusDot(
                  status: _busy ? FsStatus.working : FsStatus.idle,
                  label: _busy ? 'Working…' : 'Idle',
                ),
              ],
            ),
          ),
        ]),
      ],
    );

    return GalleryPage(
      title: 'Progress',
      note:
          'Show progress only after 300ms. The bar is accent-text when the '
          'user is waiting on it, info when it runs in the background. '
          'Animations slow down under reduce-motion.',
      children: [
        sheet,
        const SectionLabel('Reduce motion · the same loops over 3s'),
        reduced,
        const SectionLabel(
          'Live · FsDelayedProgress: the quick task shows nothing',
        ),
        live,
      ],
    );
  }
}
