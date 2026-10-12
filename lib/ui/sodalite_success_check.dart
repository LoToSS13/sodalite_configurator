import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:sodalite_configurator/ui/design_system.dart';

const _checkEase = Cubic(0.22, 1, 0.36, 1);
const _bobEase = Cubic(0.34, 1.35, 0.64, 1);

/// An entrance cue for a completed, explicitly requested check.
class SodaliteSuccessCheck extends StatefulWidget {
  const SodaliteSuccessCheck({super.key});

  @override
  State<SodaliteSuccessCheck> createState() => _SodaliteSuccessCheckState();
}

class _SodaliteSuccessCheckState extends State<SodaliteSuccessCheck> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  bool _started = false;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
    if (_reduceMotion) {
      _controller.value = 1;
    } else if (!_started) {
      _controller.forward();
    }
    _started = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: 64,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _reduceMotion ? 1.0 : _controller.value;
          final eased = _checkEase.transform(t);
          final bob = _bobEase.transform(t);
          final draw = _checkEase.transform(((t - .16) / .84).clamp(0.0, 1.0));
          final icon = CustomPaint(painter: _SuccessCheckPainter(draw));
          if (_reduceMotion) return icon;
          return Opacity(
            opacity: eased,
            child: Transform.translate(
              offset: Offset(0, 40 * (1 - bob)),
              child: Transform.rotate(
                angle: (1 - eased) * 80 * math.pi / 180,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 10 * (1 - eased), sigmaY: 10 * (1 - eased)),
                  child: icon,
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _SuccessCheckPainter extends CustomPainter {
  const _SuccessCheckPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SodaliteColors.success
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 23, paint);

    final check = Path()
      ..moveTo(center.dx - 12, center.dy)
      ..lineTo(center.dx - 3, center.dy + 9)
      ..lineTo(center.dx + 14, center.dy - 10);
    final metric = check.computeMetrics().first;
    canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
  }

  @override
  bool shouldRepaint(_SuccessCheckPainter oldDelegate) => oldDelegate.progress != progress;
}
