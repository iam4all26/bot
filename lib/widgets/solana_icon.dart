import 'package:flutter/material.dart';

class SolanaIcon extends StatelessWidget {
  final double size;
  final Color color;

  const SolanaIcon({super.key, this.size = 24, this.color = const Color(0xFF14F195)});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SolanaPainter(color),
    );
  }
}

class _SolanaPainter extends CustomPainter {
  final Color color;
  _SolanaPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double w = size.width;
    final double h = size.height;
    
    // Solana logo consists of 3 parallelograms
    final path1 = Path()
      ..moveTo(w * 0.15, h * 0.25)
      ..lineTo(w * 0.85, h * 0.25)
      ..lineTo(w * 0.70, h * 0.40)
      ..lineTo(w * 0.00, h * 0.40)
      ..close();

    final path2 = Path()
      ..moveTo(w * 0.15, h * 0.60)
      ..lineTo(w * 0.85, h * 0.60)
      ..lineTo(w * 1.00, h * 0.75)
      ..lineTo(w * 0.30, h * 0.75)
      ..close();

    final path3 = Path()
      ..moveTo(w * 0.15, h * 0.95)
      ..lineTo(w * 0.85, h * 0.95)
      ..lineTo(w * 0.70, h * 1.10)
      ..lineTo(w * 0.00, h * 1.10)
      ..close();

    // Adjusting positions to center them vertically
    canvas.save();
    canvas.translate(0, -h * 0.15);
    canvas.drawPath(path1, paint);
    canvas.drawPath(path2, paint);
    canvas.drawPath(path3, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
