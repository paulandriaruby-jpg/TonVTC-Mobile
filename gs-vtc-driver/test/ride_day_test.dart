import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gs_vtc_driver/util/paris_time.dart';
import 'package:gs_vtc_driver/widgets/ride_day.dart';

void main() {
  final now = parisTime(2026, 11, 9, 22, 30);

  test('aujourd\'hui, demain et plus tard se comptent à minuit', () {
    expect(rideDay(parisTime(2026, 11, 9, 23, 50), now), RideDay.today);
    // Départ déjà passé (course en cours) : aujourd'hui.
    expect(rideDay(parisTime(2026, 11, 9, 21, 0), now), RideDay.today);
    // Dans 2 h mais après minuit : demain.
    expect(rideDay(parisTime(2026, 11, 10, 0, 30), now), RideDay.tomorrow);
    expect(rideDay(parisTime(2026, 11, 10, 23, 59), now), RideDay.tomorrow);
    expect(rideDay(parisTime(2026, 11, 11, 0, 0), now), RideDay.later);
    // Fin de mois.
    expect(rideDay(parisTime(2026, 12, 1, 8, 0), parisTime(2026, 11, 30, 9, 0)), RideDay.tomorrow);
  });

  test('"Départ dans" seulement dans les 2 heures', () {
    expect(departureSoon(parisTime(2026, 11, 9, 23, 15), now), 'Départ dans 45 min');
    expect(departureSoon(parisTime(2026, 11, 9, 23, 50), now), 'Départ dans 1 h 20');
    expect(departureSoon(parisTime(2026, 11, 10, 0, 30), now), 'Départ dans 2 h');
    expect(departureSoon(parisTime(2026, 11, 10, 0, 31), now), isNull);
    expect(departureSoon(parisTime(2026, 11, 9, 22, 0), now), isNull);
  });

  testWidgets('intertitre avec le nombre de courses', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: DayHeader(tone: DayTone.today, count: 2))));
    expect(find.text('AUJOURD\'HUI (2)'), findsOneWidget);
  });
}
