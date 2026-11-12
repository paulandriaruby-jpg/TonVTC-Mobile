import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gs_vtc_client/api/api_client.dart';
import 'package:gs_vtc_client/api/client_api.dart';
import 'package:gs_vtc_client/auth/session_store.dart';
import 'package:gs_vtc_client/models/models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response json(Object body, [int status = 200]) => http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> ride({Map<String, dynamic>? rating, bool rate = false}) => {
      'id': 7, 'reference': 'GSV-123456789012', 'status': 'completed', 'payment_status': 'paid',
      'pickup_address': 'Chambéry', 'destination_address': 'Annecy', 'departure_at': '2026-11-01T09:00:00Z', 'quoted_price': '36.20',
      'driver': {'id': 1, 'name': 'Marc Petit', 'photo_url': '/api/v1/driver_photos/abc'}, 'permissions': {'cancel': false, 'rate': rate}, 'rating': rating,
    };

void main() {
  late List<http.Request> sent;

  ClientApi api(http.Response Function(http.Request) handler) {
    sent = [];
    final store = MemorySessionStore()..value = const StoredSession(token: 't', refreshToken: 'r', sessionId: 1);
    return ClientApi(ApiClient(baseUrl: 'http://api', store: store, client: MockClient((request) async {
      sent.add(request);
      return handler(request);
    })));
  }

  test('une course terminée à noter, puis notée', () {
    final toRate = Ride.fromJson(ride(rate: true));
    expect(toRate.canRate, isTrue);
    expect(toRate.rating, isNull);

    expect(toRate.driverPhotoUrl, '/api/v1/driver_photos/abc');

    final rated = Ride.fromJson(ride(rating: {'id': 1, 'booking_id': 7, 'stars': 4, 'comment': 'Très bien'}));
    expect(rated.canRate, isFalse);
    expect(rated.rating?.stars, 4);
    expect(rated.rating?.comment, 'Très bien');
  });

  test('la note est envoyée sur la course, sans commentaire vide', () async {
    final client = api((_) => json({'id': 1, 'booking_id': 7, 'stars': 5, 'comment': null}, 201));
    final rating = await client.rate(7, stars: 5, comment: '');
    expect(rating.stars, 5);
    expect(sent.single.url.path, '/api/v1/bookings/7/rating');
    expect(jsonDecode(sent.single.body), {'stars': 5});
  });

  test('le message à l\'équipe, rattaché ou non à une course', () async {
    final client = api((_) => json({'id': 3}, 201));
    await client.sendFeedback(category: 'problem', body: 'Objet oublié', bookingId: 7);
    await client.sendFeedback(category: 'suggestion', body: 'Paiement en espèces');
    expect(sent.map((r) => r.url.path), everyElement('/api/v1/feedbacks'));
    expect(jsonDecode(sent[0].body), {'category': 'problem', 'body': 'Objet oublié', 'booking_id': 7});
    expect(jsonDecode(sent[1].body), {'category': 'suggestion', 'body': 'Paiement en espèces'});
  });
}
