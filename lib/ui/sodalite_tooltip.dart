import 'package:flutter/material.dart';
import 'package:sodalite_configurator/ui/design_system.dart';

const _tooltipAnimation = AnimationStyle(
  duration: Duration(milliseconds: 150),
  reverseDuration: Duration(milliseconds: 50),
  curve: Curves.easeOut,
  reverseCurve: Curves.easeOut,
);

/// Shared tooltip appearance and motion for the configurator.
class SodaliteTooltip extends StatelessWidget {
  const SodaliteTooltip({super.key, required this.message, required this.child, this.excludeFromSemantics = false});

  final String message;
  final Widget child;
  final bool excludeFromSemantics;

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return child;

    final reduceMotion = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
    return RawTooltip(
      semanticsTooltip: excludeFromSemantics ? null : message,
      hoverDelay: const Duration(milliseconds: 80),
      dismissDelay: Duration.zero,
      ignorePointer: true,
      animationStyle: reduceMotion ? AnimationStyle.noAnimation : _tooltipAnimation,
      positionDelegate: _positionTooltip,
      tooltipBuilder: (context, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(animation),
          alignment: Alignment.bottomCenter,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: SodaliteColors.text,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 42, offset: const Offset(0, 4)),
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFFF0F0F0)),
                ),
              ),
            ),
          ),
        ),
      ),
      child: child,
    );
  }
}

Offset _positionTooltip(TooltipPositionContext context) {
  const gap = 8.0;
  final width = context.tooltipSize.width;
  final height = context.tooltipSize.height;
  final x = (context.target.dx - width / 2).clamp(
    gap,
    (context.overlaySize.width - width - gap).clamp(gap, double.infinity),
  );
  final above = context.target.dy - context.targetSize.height / 2 - height - gap;
  final below = context.target.dy + context.targetSize.height / 2 + gap;
  final y = above >= gap ? above : below;
  return Offset(x, y.clamp(gap, (context.overlaySize.height - height - gap).clamp(gap, double.infinity)));
}
