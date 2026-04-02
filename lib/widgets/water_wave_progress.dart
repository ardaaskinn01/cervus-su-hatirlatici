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
                  color: (isOverflow ? Colors.blue : const Color(0xFF0EA5E9)).withOpacity(0.1),
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
                    secondaryColor: const Color(0xFF7DD3FC).withOpacity(0.5),
                  ),
                );
              },
            ),
          ),

          // ─── TAŞMA EFEKTİ (Dışarıya Sızan Su) ─────────────────────────
          if (isOverflow)
            AnimatedBuilder(
              animation: _spillController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: OverflowPainter(
                    animationValue: _spillController.value,
                    color: const Color(0xFF0EA5E9),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ─── Taşma Çizici (Overflow) ────────────────────────────────────────
class OverflowPainter extends CustomPainter {
  final double animationValue;
  final Color color;

  OverflowPainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = color.withOpacity(0.8)..style = PaintingStyle.fill;
    
    // Sürahinin ağız ucu (Spout Tip): w * 0.15, h * 0.15
    final spoutX = w * 0.15;
    final spoutY = h * 0.15;

    // Damla 1
    double d1Progress = (animationValue + 0.0) % 1.0;
    canvas.drawCircle(
      Offset(spoutX - (d1Progress * 20), spoutY + (d1Progress * h * 0.6)),
      4 * (1 - d1Progress),
      paint
    );

    // Damla 2
    double d2Progress = (animationValue + 0.3) % 1.0;
    canvas.drawCircle(
      Offset(spoutX - (d2Progress * 10), spoutY + (d2Progress * h * 0.5)),
      3 * (1 - d2Progress),
      paint
    );

    // Damla 3
    double d3Progress = (animationValue + 0.6) % 1.0;
    canvas.drawCircle(
      Offset(spoutX - (d3Progress * 25), spoutY + (d3Progress * h * 0.7)),
      5 * (1 - d3Progress),
      paint
    );
    
    // Ağızdan ufak bir su sızıntısı hattı
    final leakPath = Path();
    leakPath.moveTo(spoutX, spoutY);
    leakPath.quadraticBezierTo(spoutX - 5, spoutY + 10, spoutX - 8, spoutY + 25);
    
    final leakPaint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
      
    canvas.drawPath(leakPath, leakPaint);
  }

  @override
  bool shouldRepaint(OverflowPainter oldDelegate) => true;
}

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
      ..color = const Color(0xFF0EA5E9).withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()..color = Colors.white.withOpacity(0.3)..style = PaintingStyle.fill;

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
    
    // Elit Kristal Karaf (Zarif S-Curve Boyun ve Yuvarlak Gövde)
    path.moveTo(w * 0.38, h * 0.22); // Girdi: Boyun başı
    path.lineTo(w * 0.62, h * 0.22); // Boyun sağ taraf
    
    // Sağ boyundan omuza S-Kavis
    path.cubicTo(w * 0.62, h * 0.35, w * 0.78, h * 0.40, w * 0.82, h * 0.55);
    
    // Sağ gövdeden tabana yumuşak kavis
    path.cubicTo(w * 0.88, h * 0.75, w * 0.75, h * 0.90, w * 0.50, h * 0.92);
    
    // Sol tarafa simetrik geçiş
    path.cubicTo(w * 0.25, h * 0.90, w * 0.12, h * 0.75, w * 0.18, h * 0.55);
    
    // Sol omuzdan boyuna S-Kavis
    path.cubicTo(w * 0.22, h * 0.40, w * 0.38, h * 0.35, w * 0.38, h * 0.22);
    
    path.close();
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

    double topLimit = size.height * 0.15;
    double bottomLimit = size.height * 0.9;
    double usableHeight = bottomLimit - topLimit;
    
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
