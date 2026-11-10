import 'package:flutter/material.dart';

import '../theme.dart';

// Symbole du logo (même dessin que le favicon du site) : "T" blanc dont le pied est une route, point orange.
class Logo extends StatelessWidget {
  const Logo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _LogoPainter());
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 64;
    Rect rect(double x, double y, double w, double h) => Rect.fromLTWH(x * unit, y * unit, w * unit, h * unit);
    canvas.drawRRect(RRect.fromRectAndRadius(rect(0, 0, 64, 64), Radius.circular(14 * unit)), Paint()..color = AppColors.brand);
    final white = Paint()..color = Colors.white;
    canvas.drawRRect(RRect.fromRectAndRadius(rect(12, 13, 34, 11), Radius.circular(3 * unit)), white);
    canvas.drawRRect(RRect.fromRectAndRadius(rect(22, 13, 14, 39), Radius.circular(3 * unit)), white);
    final lane = Paint()..color = AppColors.brand;
    canvas.drawRect(rect(28, 28, 2, 6), lane);
    canvas.drawRect(rect(28, 38, 2, 6), lane);
    canvas.drawCircle(Offset(50 * unit, 18.5 * unit), 6.5 * unit, Paint()..color = AppColors.accent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
