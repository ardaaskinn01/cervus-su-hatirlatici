import 'package:flutter/material.dart';
import 'dart:math' as math;

class WaterWaveProgress extends StatefulWidget {
  final double progress; // 0.0'dan (boş) 1.0'a (dolu) kadar (taşma için 1.0+ olabilir)
  final double size; 

  const WaterWaveProgress({super.key, required this.progress, this.size = 280});

  @override
  State<WaterWaveProgress> createState() => _WaterWaveProgressState();
}

class _WaterWaveProgressState extends State<WaterWaveProgress> with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _spillController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _spillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _spillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isOverflow = widget.progress > 1.0;
    
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        clipBehavior: Clip.none, // Dışarı taşacak su damlaları için
        alignment: Alignment.center,
        children: [
          // ─── Arkaplan Glow ──────────────────────────────────────────
          Container(
            width: widget.size * 1.1,
            height: widget.size * 1.1,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isOverflow ? Colors.blue : const Color(0xFF0EA5E9)).withValues(alpha: 0.1),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
          ),

          // ─── Sürahi Dış Çerçevesi (Cam) ──────────────────────────────
          CustomPaint(
            size: Size(widget.size, widget.size),
            painter: PitcherOutlinePainter(),
          ),
          
          // ─── İçerideki Su (Dalgalar) ──────────────────────────────────
          ClipPath(
            clipper: PitcherClipper(),
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: WaterWavePainter(
                    progress: widget.progress.clamp(0.0, 1.0),
                    animationValue: _waveController.value,
                    primaryColor: const Color(0xFF0EA5E9),
                    secondaryColor: const Color(0xFF7DD3FC).withValues(alpha: 0.5),
                  ),
                );
              },
            ),
          ),

        ],
      ),
    );
  }
}

// ─── Taşma Çizici (Overflow) ────────────────────────────────────────


class PitcherClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => _getPitcherPath(size);
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class PitcherOutlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = _getPitcherPath(size);
    final paint = Paint()
      ..color = const Color(0xFF0EA5E9).withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()..color = Colors.white.withValues(alpha: 0.3)..style = PaintingStyle.fill;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);
    
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

Path _getPitcherPath(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    
    // Düz ve modern kap formu (Diğer kaplarla uyumlu)
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      const Radius.circular(20),
    ));
    
    return path;
}

class WaterWavePainter extends CustomPainter {
  final double progress;
  final double animationValue;
  final Color primaryColor;
  final Color secondaryColor;

  WaterWavePainter({required this.progress, required this.animationValue, required this.primaryColor, required this.secondaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;
    
    Paint paintBackground = Paint()..color = secondaryColor..style = PaintingStyle.fill;
    Paint paintForeground = Paint()..color = primaryColor..style = PaintingStyle.fill;

    double topLimit = 0;
    double bottomLimit = size.height;
    double usableHeight = size.height;
    
    double waterMaxY = bottomLimit - (usableHeight * progress);
    double waveAmplitude = (progress >= 1.0 || progress <= 0.0) ? 0.0 : 8.0;
    
    Path pathBackground = Path();
    Path pathForeground = Path();

    pathBackground.moveTo(0, waterMaxY);
    pathForeground.moveTo(0, waterMaxY);

    for (double i = 0; i <= size.width; i++) {
        double yBack = waterMaxY + math.sin((i / size.width * 2 * math.pi) + (animationValue * 2 * math.pi)) * waveAmplitude;
        double yFront = waterMaxY + math.sin((i / size.width * 2 * math.pi) + (animationValue * 2 * math.pi) + math.pi) * waveAmplitude;
        pathBackground.lineTo(i, yBack);
        pathForeground.lineTo(i, yFront);
    }

    pathBackground.lineTo(size.width, size.height);
    pathBackground.lineTo(0, size.height);
    pathBackground.close();

    pathForeground.lineTo(size.width, size.height);
    pathForeground.lineTo(0, size.height);
    pathForeground.close();

    canvas.drawPath(pathBackground, paintBackground);
    canvas.drawPath(pathForeground, paintForeground);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
