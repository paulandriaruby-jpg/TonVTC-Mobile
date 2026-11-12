// Règles de réservation, identiques au site : au moins 2 h avant le départ, créneaux d'un quart d'heure,
// retour après l'aller, coordonnées complètes. Le serveur revérifie tout à la création. Les heures sont celles de
// Paris, quel que soit le fuseau du téléphone.

import '../util/paris_time.dart';

const minimumNotice = Duration(hours: 2);
const maxChildSeats = 3;

// Premier créneau réservable : maintenant + 2 h, arrondi au quart d'heure suivant.
DateTime minimumDeparture(DateTime now) {
  final earliest = now.add(minimumNotice);
  final quarter = const Duration(minutes: 15).inMilliseconds;
  final rounded = (earliest.millisecondsSinceEpoch / quarter).ceil() * quarter;
  return inParis(DateTime.fromMillisecondsSinceEpoch(rounded, isUtc: true));
}

// Ramène une heure choisie au quart d'heure (09:07 -> 09:15), à l'heure de Paris.
DateTime roundToQuarter(DateTime value) {
  final local = inParis(value);
  final extra = local.minute % 15;
  final base = parisTime(local.year, local.month, local.day, local.hour, local.minute).subtract(Duration(minutes: extra));
  return extra == 0 ? base : base.add(const Duration(minutes: 15));
}

String? tripError({required bool hasPickup, required bool hasDestination, DateTime? departure, required bool roundTrip, DateTime? returning, required DateTime now}) {
  if (!hasPickup || !hasDestination) return 'Choisissez vos deux adresses.';
  if (departure == null) return 'Choisissez la date et l\'heure de départ.';
  if (departure.isBefore(minimumDeparture(now))) return 'Réservez au moins 2 heures avant le départ.';
  if (roundTrip) {
    if (returning == null) return 'Choisissez la date et l\'heure de retour.';
    if (!returning.isAfter(departure)) return 'Le retour doit être après le départ.';
  }
  return null;
}

final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final _phone = RegExp(r'^\+?[\d\s().-]+$');

// Coordonnées manquantes ou invalides (vide : la réservation peut être confirmée).
List<String> customerProblems({required String firstName, required String lastName, required String email, required String phone}) => [
      if (firstName.trim().isEmpty) 'prénom',
      if (lastName.trim().isEmpty) 'nom',
      if (!_email.hasMatch(email.trim())) 'e-mail',
      if (!_phone.hasMatch(phone.trim()) || phone.replaceAll(RegExp(r'\D'), '').length < 8) 'téléphone',
    ];

// Prix : course (aller-retour compris) + équipements enfant, comptés à chaque trajet.
double offerTotal({required double price, required int babySeats, required int boosterSeats, required double babyPrice, required double boosterPrice, required bool roundTrip}) =>
    price + (babySeats * babyPrice + boosterSeats * boosterPrice) * (roundTrip ? 2 : 1);

// Code promo d'abord, puis l'avoir, jamais sous zéro.
({double promo, double credit, double due}) discounted(double total, double promo, double creditBalance, bool useCredit) {
  final promoApplied = promo.clamp(0, total).toDouble();
  final afterPromo = total - promoApplied;
  final credit = useCredit ? creditBalance.clamp(0, afterPromo).toDouble() : 0.0;
  double round(double v) => (v * 100).roundToDouble() / 100;
  return (promo: round(promoApplied), credit: round(credit), due: round(afterPromo - credit));
}
