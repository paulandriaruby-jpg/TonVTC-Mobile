import 'package:flutter/material.dart';

import '../theme.dart';

// Code couleur de l'onglet "À venir" : aujourd'hui (vert), demain (bleu), plus tard (blanc). Les jours se comptent
// à minuit, à l'heure du téléphone ; une course déjà commencée (départ passé) compte pour aujourd'hui.
enum RideDay { today, tomorrow, later }

RideDay rideDay(DateTime departure, DateTime now) {
  final local = departure.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  if (!day.isAfter(today)) return RideDay.today;
  if (day == DateTime(today.year, today.month, today.day + 1)) return RideDay.tomorrow;
  return RideDay.later;
}

// "Départ dans 45 min" / "Départ dans 1 h 20" : seulement dans les 2 heures avant le départ.
String? departureSoon(DateTime departure, DateTime now) {
  final minutes = departure.difference(now).inMinutes;
  if (minutes <= 0 || minutes > 120) return null;
  if (minutes < 60) return 'Départ dans $minutes min';
  final rest = minutes % 60;
  return 'Départ dans ${minutes ~/ 60} h${rest == 0 ? '' : ' ${rest.toString().padLeft(2, '0')}'}';
}

class DayTone {
  const DayTone({required this.label, required this.color, required this.background, required this.border});

  final String label;
  // Texte, point de l'intertitre et étiquette ; fond et bordure de la carte.
  final Color color;
  final Color background;
  final Color border;

  static const today = DayTone(label: 'Aujourd\'hui', color: AppColors.success, background: Color(0xFFE6F7F2), border: Color(0xFF7CCFB9));
  static const tomorrow = DayTone(label: 'Demain', color: AppColors.brand, background: Color(0xFFEEF1FF), border: Color(0xFFADBAFF));
  static const later = DayTone(label: 'Plus tard', color: Color(0xFF5F6B7A), background: Colors.white, border: Color(0xFFE2E8F0));

  static DayTone of(RideDay day) => switch (day) {
        RideDay.today => today,
        RideDay.tomorrow => tomorrow,
        RideDay.later => later,
      };
}

// Intertitre d'un groupe : point de couleur, jour et nombre de courses.
class DayHeader extends StatelessWidget {
  const DayHeader({super.key, required this.tone, required this.count});

  final DayTone tone;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 2),
      child: Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: tone == DayTone.later ? const Color(0xFF94A3B8) : tone.color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text('${tone.label.toUpperCase()} ($count)', style: TextStyle(color: tone == DayTone.later ? AppColors.muted : tone.color, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: .6)),
      ]),
    );
  }
}
