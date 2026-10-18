import 'package:flutter/material.dart';
import 'package:pyro_ui/pyro_ui.dart';

/// A sample floating layer: overlay surface, border, radius-md, popover
/// shadow.
class _Layer extends StatelessWidget {
  const _Layer(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    return Container(
      width: 240,
      padding: const EdgeInsets.all(PrSpacing.s3),
      decoration: BoxDecoration(
        color: c.surfaceOverlay,
        border: Border.all(color: c.borderOverlay),
        borderRadius: PrRadii.md,
        boxShadow: PrShadows.of(context).popover,
      ),
      child: Text(text, style: PrText.small.copyWith(color: c.textPrimary)),
    );
  }
}

/// An anchor button that opens a layer below itself.
class _Anchored extends StatefulWidget {
  const _Anchored(this.label);

  final String label;

  @override
  State<_Anchored> createState() => _AnchoredState();
}

class _AnchoredState extends State<_Anchored> {
  final _controller = OverlayPortalController();

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    return PrAnchoredOverlay(
      controller: _controller,
      onDismiss: () => setState(_controller.hide),
      overlayBuilder: (context) => const _Layer(
        'Below the anchor with a 4px gap; flips above near the bottom of '
        'the window and shifts to stay 8px inside it. Esc or a click '
        'outside closes it.',
      ),
      child: PrInteractive(
        onPressed: () => setState(_controller.toggle),
        builder: (context, states) => PrFocusRing.outside(
          visible: states.contains(WidgetState.focused),
          child: Container(
            height: PrSizes.control,
            padding: const EdgeInsets.symmetric(horizontal: PrSpacing.s3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PrStateColor.resolve(states, {
                WidgetState.pressed: c.surfacePressed,
                WidgetState.hovered: c.surfaceHover,
              }, fallback: c.surfaceRaised),
              border: Border.all(color: c.borderControl),
              borderRadius: PrRadii.sm,
            ),
            child: Text(
              widget.label,
              style: PrText.bodyStrong.copyWith(color: c.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

/// A right-click area that opens a layer at the pointer.
class _AtPoint extends StatefulWidget {
  const _AtPoint();

  @override
  State<_AtPoint> createState() => _AtPointState();
}

class _AtPointState extends State<_AtPoint> {
  final _controller = OverlayPortalController();
  Offset _at = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    return PrAnchoredOverlay(
      controller: _controller,
      position: _at,
      onDismiss: () => setState(_controller.hide),
      overlayBuilder: (context) => const _Layer(
        'Opened at the pointer; near the right edge it opens to the left.',
      ),
      child: GestureDetector(
        onSecondaryTapUp: (details) => setState(() {
          _at = details.localPosition;
          _controller.show();
        }),
        child: Container(
          height: 120,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: c.borderSubtle),
            borderRadius: PrRadii.sm,
          ),
          child: Text(
            'Right-click anywhere here',
            style: PrText.small.copyWith(color: c.textSecondary),
          ),
        ),
      ),
    );
  }
}

class OverlayPage extends StatelessWidget {
  const OverlayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(PrSpacing.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PrAnchoredOverlay',
            style: PrText.title.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: PrSpacing.s2),
          Text(
            'The positioner every floating layer uses. The anchors sit in '
            'the corners of this page so the flips and shifts show.',
            style: PrText.small.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: PrSpacing.s6),
          const _AtPoint(),
          const SizedBox(height: PrSpacing.s6),
          const Expanded(
            child: Stack(
              children: [
                Positioned(left: 0, top: 0, child: _Anchored('Top left')),
                Positioned(
                  right: 0,
                  top: 0,
                  child: _Anchored('Top right · shifts'),
                ),
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: _Anchored('Bottom left · flips'),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _Anchored('Bottom right · both'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
