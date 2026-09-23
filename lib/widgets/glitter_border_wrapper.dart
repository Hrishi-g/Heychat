import 'dart:math' as math;
import 'package:flutter/material.dart';

/// GlitterBorderWrapper renders a thin, pulsating, rotating multi-color
/// gradient boundary around its child when [isEnabled] is true.
/// When [isEnabled] is false (e.g. when the user types), it smoothly disables.
class GlitterBorderWrapper extends StatefulWidget {
  final Widget child;
  final bool isEnabled;
  final double borderRadius;
  final double strokeWidth;

  const GlitterBorderWrapper({
    super.key,
    required this.child,
    this.isEnabled = true,
    this.borderRadius = 26.0,
    this.strokeWidth = 1.1,
  });

  @override
  State<GlitterBorderWrapper> createState() => _GlitterBorderWrapperState();
}

class _GlitterBorderWrapperState extends State<GlitterBorderWrapper>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseAnimation = Tween<double>(begin: 0.70, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    if (widget.isEnabled) {
      _rotationController.repeat();
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant GlitterBorderWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEnabled != oldWidget.isEnabled) {
      if (widget.isEnabled) {
        _rotationController.repeat();
        _pulseController.repeat(reverse: true);
      } else {
        _rotationController.stop();
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_rotationController, _pulseController]),
      builder: (context, child) {
        return CustomPaint(
          foregroundPainter: widget.isEnabled
              ? _GlitterBorderPainter(
                  angle: _rotationController.value * 2 * math.pi,
                  pulse: _pulseAnimation.value,
                  borderRadius: widget.borderRadius,
                  strokeWidth: widget.strokeWidth,
                )
              : null,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _GlitterBorderPainter extends CustomPainter {
  final double angle;
  final double pulse;
  final double borderRadius;
  final double strokeWidth;

  _GlitterBorderPainter({
    required this.angle,
    required this.pulse,
    required this.borderRadius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(borderRadius - (strokeWidth / 2)),
    );

    // Exact palette from user screenshot: Purple/Violet fading softly into amber/yellow and back
    final gradient = SweepGradient(
      center: Alignment.center,
      startAngle: 0.0,
      endAngle: 2 * math.pi,
      transform: GradientRotation(angle),
      colors: [
        const Color(0xFF7C3AED)
            .withValues(alpha: 0.90 * pulse), // Purple (like top-left in image)
        const Color(0xFF9333EA).withValues(alpha: 0.75 * pulse),
        const Color(0xFFC084FC)
            .withValues(alpha: 0.35 * pulse), // Faint transition
        const Color(0xFFFEF08A).withValues(alpha: 0.40 * pulse),
        const Color(0xFFF59E0B).withValues(
            alpha: 0.95 * pulse), // Vibrant warm gold (like right in image)
        const Color(0xFFFBBF24).withValues(alpha: 0.85 * pulse),
        const Color(0xFFF472B6)
            .withValues(alpha: 0.40 * pulse), // Subtle peach/pink transition
        const Color(0xFF7C3AED).withValues(alpha: 0.90 * pulse),
      ],
      stops: const [0.0, 0.16, 0.36, 0.52, 0.70, 0.84, 0.94, 1.0],
    );

    // Razor-thin crisp glowing border as in the screenshot (no thick fuzzy blur)
    final borderPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _GlitterBorderPainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.pulse != pulse ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
