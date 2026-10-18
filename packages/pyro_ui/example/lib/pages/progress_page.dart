import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pyro_ui/pyro_ui.dart';

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
    final c = PrColors.of(context);

    Widget column(double? width, List<Widget> children) => SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: PrSpacing.s2,
        children: children,
      ),
    );

    Widget labelled(Widget indicator, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        indicator,
        Text(label, style: PrText.small.copyWith(color: c.textSecondary)),
      ],
    );

    Widget panel({required bool reduceMotion}) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: Container(
        height: PrPanel.headerHeight + 40 + 2,
        decoration: BoxDecoration(
          border: Border.all(color: c.borderSubtle),
          borderRadius: PrRadii.sm,
        ),
        clipBehavior: Clip.antiAlias,
        child: PrPanel(
          title: 'Assets',
          icon: PrIcons.folder,
          headerProgress: const PrProgressBar(),
          body: const SizedBox.shrink(),
        ),
      ),
    );

    final sheet = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 40,
      children: [
        column(280, [
          const SectionLabel(
            'Indeterminate bar',
            detail: '2px · under a panel header',
          ),
          panel(reduceMotion: false),
          const SizedBox(height: PrSpacing.s1),
          const SectionLabel('Determinate'),
          const PrProgressBar(value: 0.62),
          const SizedBox(height: PrSpacing.s1),
          const SectionLabel('Background (info) · determinate'),
          const PrProgressBar(value: 0.62, tone: PrProgressTone.background),
        ]),
        column(null, [
          const SectionLabel('Spinner · 14 / 16'),
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: PrSpacing.s3,
            children: [
              const PrSpinner(),
              const PrSpinner(size: 16),
              labelled(const PrSpinner(), 'Building…'),
            ],
          ),
        ]),
        column(null, const [
          SectionLabel('Status dot · always with a label'),
          PrStatusDot(status: PrStatus.idle, label: 'Idle'),
          PrStatusDot(status: PrStatus.working, label: 'Hot reloading…'),
          PrStatusDot(status: PrStatus.ok, label: 'Running · 60 fps'),
          PrStatusDot(status: PrStatus.error, label: 'Crashed — see console'),
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
          const PrSpinner(),
          const PrStatusDot(status: PrStatus.working, label: 'Hot reloading…'),
        ],
      ),
    );

    final live = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 40,
      children: [
        column(280, [
          Row(
            spacing: PrSpacing.s2,
            children: [
              PrButton(
                label: 'Quick task (200ms)',
                onPressed: () => _run(const Duration(milliseconds: 200)),
              ),
              PrButton(
                label: 'Long task (2s)',
                onPressed: () => _run(const Duration(seconds: 2)),
              ),
            ],
          ),
          SizedBox(
            height: PrProgressBar.height,
            child: PrDelayedProgress(busy: _busy, child: const PrProgressBar()),
          ),
        ]),
        column(null, [
          SizedBox(
            height: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                PrDelayedProgress(busy: _busy, child: const PrSpinner()),
                PrStatusDot(
                  status: _busy ? PrStatus.working : PrStatus.idle,
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
          'Live',
          detail: 'PrDelayedProgress: the quick task shows nothing',
        ),
        live,
      ],
    );
  }
}
