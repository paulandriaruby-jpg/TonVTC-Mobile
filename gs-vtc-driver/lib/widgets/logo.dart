import 'package:flutter/material.dart';

import '../theme.dart';

// Symbole du logo sur sa tuile bleu nuit (version chauffeur, pour ne pas confondre avec l'app client, tuile bleue) :
// la barre du T dessine les Alpes, le pied est la route, le point orange l'arrivée.
// Géométrie de la version petite taille du kit, dans un carré de 256.
class Logo extends StatelessWidget {
  const Logo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _LogoPainter());
}

class _LogoPainter extends CustomPainter {
  // Contour du T (crêtes des Alpes, puis le pied), points du SVG.
  static const _mark = [
    Offset(12, 110), Offset(12, 70), Offset(88, 26.1), Offset(128, 49.2), Offset(172, 23.8), Offset(244, 65.4),
    Offset(244, 110), Offset(160, 110), Offset(160, 154), Offset(96, 154), Offset(96, 110),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 256;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(48 * unit)), Paint()..color = AppColors.ink);
    // Le symbole est réduit à 80 % et centré dans la tuile, comme dans le SVG.
    Offset point(Offset p) => Offset(25.6 + p.dx * .8, 21.8 + p.dy * .8) * unit;
    canvas.drawPath(Path()..addPolygon(_mark.map(point).toList(), true), Paint()..color = Colors.white);
    canvas.drawCircle(point(const Offset(128, 200)), 30 * .8 * unit, Paint()..color = AppColors.accent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
