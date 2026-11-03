import 'package:flutter_test/flutter_test.dart';
import 'package:gs_vtc_client/booking/rules.dart';

void main() {
  test('premier départ possible : 2 h après, au quart d’heure suivant', () {
    expect(minimumDeparture(DateTime(2026, 11, 3, 10, 2)), DateTime(2026, 11, 3, 12, 15));
    expect(minimumDeparture(DateTime(2026, 11, 3, 10, 0)), DateTime(2026, 11, 3, 12, 0));
    expect(roundToQuarter(DateTime(2026, 11, 3, 9, 7)), DateTime(2026, 11, 3, 9, 15));
    expect(roundToQuarter(DateTime(2026, 11, 3, 9, 45)), DateTime(2026, 11, 3, 9, 45));
  });

  test('trajet : adresses, délai de 2 h et retour après l’aller', () {
    final now = DateTime(2026, 11, 3, 10, 0);
    String? error({DateTime? departure, bool roundTrip = false, DateTime? returning, bool both = true}) =>
        tripError(hasPickup: both, hasDestination: true, departure: departure, roundTrip: roundTrip, returning: returning, now: now);
    expect(error(both: false), 'Choisissez vos deux adresses.');
    expect(error(departure: DateTime(2026, 11, 3, 11, 0)), 'Réservez au moins 2 heures avant le départ.');
    expect(error(departure: DateTime(2026, 11, 3, 12, 0)), isNull);
    expect(error(departure: DateTime(2026, 11, 3, 12, 0), roundTrip: true, returning: DateTime(2026, 11, 3, 12, 0)), 'Le retour doit être après le départ.');
  });

  test('coordonnées manquantes : la réservation reste bloquée', () {
    expect(customerProblems(firstName: 'Léa', lastName: 'Morel', email: 'lea@example.com', phone: '06 12 34 56 78'), isEmpty);
    expect(customerProblems(firstName: ' ', lastName: 'Morel', email: 'lea@', phone: '06'), ['prénom', 'e-mail', 'téléphone']);
  });

  test('total avec équipements enfant comptés à chaque trajet, puis code promo et avoir', () {
    expect(offerTotal(price: 100, babySeats: 1, boosterSeats: 1, babyPrice: 14, boosterPrice: 9, roundTrip: true), 146);
    final split = discounted(146, 10, 200, true);
    expect(split.promo, 10);
    expect(split.credit, 136);
    expect(split.due, 0);
    expect(discounted(146, 10, 200, false).due, 136);
  });
}
