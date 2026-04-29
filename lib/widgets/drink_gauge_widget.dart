import 'dart:math' as math;
import 'package:flutter/material.dart';

class DrinkGaugeWidget extends StatefulWidget {
  final String label;
  final double currentValue;
  final double maxValue;
  final String unit;
  final IconData icon;
  final Color color;

  const DrinkGaugeWidget({
    super.key,
    required this.label,
    required this.currentValue,
    required this.maxValue,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  State<DrinkGaugeWidget> createState() => _DrinkGaugeWidgetState();
}

class _DrinkGaugeWidgetState extends State<DrinkGaugeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _checkAnimation();
  }

  @override
  void didUpdateWidget(covariant DrinkGaugeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkAnimation();
  }

  void _checkAnimation() {
    double ratio = widget.currentValue / widget.maxValue;
    if (ratio >= 0.9 && !_animationController.isAnimating) {
      _animationController.repeat(reverse: true);
    } else if (ratio < 0.9 && _animationController.isAnimating) {
      _animationController.stop();
      _animationController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double ratio = (widget.currentValue / widget.maxValue).clamp(0.0, 1.0);

    Color glowColor;
    if (ratio >= 0.9) {
      glowColor = Colors.red;
    } else if (ratio >= 0.7) {
      glowColor = Colors.orange;
    } else {
      glowColor = widget.color;
    }

    final double size = 150.0;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        double dx = 0.0;
        if (_animationController.isAnimating) {
          dx = math.sin(_animationController.value * math.pi * 4) * 4;
        }
        return Transform.translate(
          offset: Offset(dx, 0),
          child: child,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.15),
                  blurRadius: 30,
                  spreadRadius: 5,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: size,
                  height: size,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 12,
                    valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFFF1F5F9)),
                  ),
                ),
                SizedBox(
                  width: size,
                  height: size,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: ratio),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return CircularProgressIndicator(
                        value: value,
                        strokeWidth: 12,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(glowColor),
                        strokeCap: StrokeCap.round,
                      );
                    },
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, color: glowColor, size: 28),
                    const SizedBox(height: 4),
                    Text(
                      widget.currentValue.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                        height: 1.0,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      '/ ${widget.maxValue.toInt()} ${widget.unit}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}
