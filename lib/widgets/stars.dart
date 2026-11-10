import 'package:flutter/material.dart';

// Note en étoiles : lecture seule sans onChanged, sinon chaque étoile se touche (cible de 48 px).
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.value, this.onChanged, this.size = 28});

  final int value;
  final ValueChanged<int>? onChanged;
  final double size;

  static const color = Color(0xFFFFB400);
  static const labels = ['Très décevant', 'Décevant', 'Correct', 'Bien', 'Excellent'];

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var star = 1; star <= 5; star++)
        onChanged == null
            ? Icon(star <= value ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: star <= value ? color : Colors.black26)
            : Semantics(
                button: true,
                selected: star == value,
                label: '$star étoile${star > 1 ? 's' : ''} sur 5',
                child: InkResponse(
                  onTap: () => onChanged!(star),
                  radius: size * .9,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(star <= value ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: star <= value ? color : Colors.black38),
                  ),
                ),
              ),
    ]);
  }
}
