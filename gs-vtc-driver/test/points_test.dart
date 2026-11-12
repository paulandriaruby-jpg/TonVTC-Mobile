import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gs_vtc_driver/models/models.dart';
import 'package:gs_vtc_driver/screens/points_screen.dart';

Map<String, dynamic> body({int rank = 4, bool prioritized = false, int? toPriority = 16, bool enabled = true}) => {
      'score': 25, 'rank': rank, 'prioritized': prioritized, 'points_to_priority': toPriority,
      'priority': {'enabled': enabled, 'minutes': 20}, 'window_days': 90,
      'rules': [{'kind': 'ride_completed', 'label': 'Course terminée', 'points': 10}, {'kind': 'withdrawn', 'label': 'Désistement après acceptation', 'points': -15}],
      'entries': [
        {'id': 1, 'kind': 'ride_completed', 'label': 'Course terminée', 'points': 10, 'created_at': '2026-11-08T10:00:00Z', 'booking_reference': 'GSV-12345678', 'counted': true},
      ],
    };

void main() {
  test('lit le score, le rang, la priorité et l\'historique', () {
    final data = DriverPoints.fromJson(body());
    expect(data.score, 25);
    expect(data.rank, 4);
    expect(data.pointsToPriority, 16);
    expect(data.priorityEnabled, isTrue);
    expect(data.rules.last.points, -15);
    expect(data.entries.single.bookingReference, 'GSV-12345678');
    // Aucun nombre de chauffeurs dans les textes.
    expect(priorityExplanation(data), contains('20 min avant les autres'));
    expect(priorityExplanation(data), isNot(contains(RegExp(r'\d+ chauffeurs'))));

    final disabled = DriverPoints.fromJson(body(enabled: false, toPriority: null));
    expect(disabled.priorityEnabled, isFalse);
    expect(priorityExplanation(disabled), contains('désactivée'));
  });

  testWidgets('la carte montre le rang parmi les autres chauffeurs, sans leur nombre', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PointsCard(data: DriverPoints.fromJson(body(rank: 1, prioritized: true, toPriority: null)), onTap: () {}))));
    expect(find.text('25'), findsOneWidget);
    expect(find.textContaining('1er parmi les autres chauffeurs'), findsOneWidget);
    expect(find.text('Prioritaire'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PointsCard(data: DriverPoints.fromJson(body()), onTap: () {}))));
    expect(find.textContaining('4e parmi les autres chauffeurs'), findsOneWidget);
    expect(find.text('Encore 16 pts'), findsOneWidget);
  });
}
