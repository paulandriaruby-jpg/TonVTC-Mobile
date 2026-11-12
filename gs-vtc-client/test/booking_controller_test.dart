import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gs_vtc_client/api/api_client.dart';
import 'package:gs_vtc_client/api/client_api.dart';
import 'package:gs_vtc_client/auth/session_store.dart';
import 'package:gs_vtc_client/booking/booking_controller.dart';
import 'package:gs_vtc_client/models/models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response json(Object body, [int status = 200]) => http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

const quoteBody = {
  'trip_type': 'one_way', 'route': {'distance_km': 17.9, 'duration_minutes': 19}, 'pickup_kind': 'airport',
  'seat_prices': {'baby_seat': '14.00', 'booster_seat': '9.00'},
  'offers': [
    {'vehicle_type_id': 1, 'slug': 'berline', 'name': 'Berline', 'description': 'Confort', 'passenger_capacity': 4, 'luggage_capacity': 3, 'price': '44.00', 'currency': 'EUR'},
  ],
};

void main() {
  final now = DateTime(2026, 11, 3, 10, 0);
  late List<http.Request> sent;

  BookingController controller(Future<http.Response> Function(http.Request) handler, {bool signedIn = true}) {
    sent = [];
    final store = MemorySessionStore();
    if (signedIn) store.value = const StoredSession(token: 't', refreshToken: 'r', sessionId: 1);
    final client = ApiClient(baseUrl: 'http://api', store: store, client: MockClient((request) {
      sent.add(request);
      return handler(request);
    }));
    final booking = BookingController(ClientApi(client), clock: () => now)
      ..pickup = const Place(placeId: 'gva', address: 'Aéroport de Genève')
      ..destination = const Place(placeId: 'ann', address: 'Annecy, France');
    return booking;
  }

  test('"Voir les prix" : le devis fait passer au véhicule, un refus reste sur le trajet', () async {
    final booking = controller((_) async => json(quoteBody));
    await booking.showPrices();
    expect(booking.step, BookingStep.vehicle);
    expect(booking.offer?.name, 'Berline');
    expect(booking.quote?.pickupKind, 'airport');
    expect(jsonDecode(sent.single.body), containsPair('departure_at', DateTime(2026, 11, 3, 12, 0).toUtc().toIso8601String()));

    final refused = controller((_) async => json({'error': {'code': 'no_route', 'message': 'Trajet hors forfait : aucun itinéraire.'}}, 422));
    await refused.showPrices();
    expect(refused.step, BookingStep.trip);
    expect(refused.error, 'Trajet hors forfait : aucun itinéraire.');
  });

  test('"Confirmer" est bloqué sans téléphone, avec ou sans compte', () async {
    final booking = controller((_) async => json(quoteBody), signedIn: false);
    await booking.showPrices();
    booking
      ..firstName = 'Léa'
      ..lastName = 'Morel'
      ..email = 'lea@example.com';
    expect(booking.canConfirm(), isFalse);
    expect(booking.missingDetails, ['téléphone']);
    await booking.confirm(signedIn: true);
    expect(booking.error, 'Complétez : téléphone.');
    expect(sent.where((r) => r.url.path == '/api/v1/bookings'), isEmpty);
  });

  test('réservation : coordonnées gardées sur le compte, vol et pancarte envoyés', () async {
    final booking = controller((request) async => switch (request.url.path) {
          '/api/v1/quotes' => json(quoteBody),
          '/api/v1/profile' => json({'user': {'first_name': 'Léa', 'last_name': 'Morel', 'email': 'lea@example.com', 'phone': '0612345678'}}),
          _ => json({'reference': 'GSV-abc', 'status': 'pending', 'payment_status': 'awaiting_payment', 'pickup_address': 'Aéroport de Genève',
              'destination_address': 'Annecy, France', 'departure_at': '2026-11-03T11:00:00Z', 'quoted_price': '58.0', 'amount_due': '58.0', 'transport_number': 'EZY1234'}, 201),
        });
    await booking.showPrices();
    booking.changeSeats(baby: 1);
    booking.toCustomer();
    booking
      ..firstName = 'Léa'
      ..lastName = 'Morel'
      ..email = 'lea@example.com'
      ..phone = '0612345678'
      ..termsAccepted = true
      ..transportNumber = 'EZY1234'
      ..signName = 'L. Morel';
    expect(booking.total, 58);
    await booking.confirm(signedIn: true);
    expect(booking.step, BookingStep.done);
    expect(sent.map((r) => '${r.method} ${r.url.path}'), contains('PATCH /api/v1/profile'));
    final body = jsonDecode(sent.last.body) as Map<String, dynamic>;
    expect(body, containsPair('customer_phone', '0612345678'));
    expect(body, containsPair('terms_accepted', true));
    expect(body, containsPair('transport_number', 'EZY1234'));
    expect(body, containsPair('sign_name', 'L. Morel'));
    expect(body, containsPair('baby_seats_count', 1));
    expect(body['pickup'], {'place_id': 'gva', 'address': 'Aéroport de Genève'});
    expect(sent.last.headers['Authorization'], 'Bearer t');
    expect(booking.created?.transportNumber, 'EZY1234');
  });

  test('Confirmer exige la case des CGV et de la confidentialité, décochée à chaque nouvelle réservation', () async {
    final booking = controller((_) async => json(quoteBody));
    await booking.showPrices();
    booking
      ..firstName = 'Léa'
      ..lastName = 'Morel'
      ..email = 'lea@example.com'
      ..phone = '0612345678';
    expect(booking.canConfirm(), isFalse);
    await booking.confirm(signedIn: true);
    expect(booking.error, 'Acceptez les conditions générales de vente et la politique de confidentialité.');
    expect(sent.where((r) => r.url.path == '/api/v1/bookings'), isEmpty);

    booking.termsAccepted = true;
    expect(booking.canConfirm(), isTrue);
    booking.restart();
    expect(booking.termsAccepted, isFalse);
  });

  test('ni aéroport ni gare : pas de vol ni de pancarte ; arrivée en gare : le train, pancarte au retour seulement', () async {
    Map<String, dynamic> quoteWith(String? pickup, String? destination) => {...quoteBody, 'pickup_kind': pickup, 'destination_kind': destination};
    Future<Map<String, dynamic>> booked(Map<String, dynamic> quote, {bool roundTrip = false}) async {
      final booking = controller((request) async => switch (request.url.path) {
            '/api/v1/quotes' => json(quote),
            '/api/v1/profile' => json({'user': {'first_name': 'Léa', 'last_name': 'Morel', 'email': 'lea@example.com', 'phone': '0612345678'}}),
            _ => json({'reference': 'GSV-abc', 'status': 'pending', 'payment_status': 'awaiting_payment', 'pickup_address': 'A',
                'destination_address': 'B', 'departure_at': '2026-11-03T11:00:00Z', 'quoted_price': '44.0', 'amount_due': '44.0'}, 201),
          });
      booking.roundTrip = roundTrip;
      if (roundTrip) booking.returning = DateTime(2026, 11, 4, 12, 0);
      await booking.showPrices();
      booking
        ..firstName = 'Léa'
        ..lastName = 'Morel'
        ..email = 'lea@example.com'
        ..phone = '0612345678'
        ..termsAccepted = true
        ..transportNumber = 'TGV 6543'
        ..signName = 'Léa Morel';
      await booking.confirm(signedIn: true);
      return jsonDecode(sent.last.body) as Map<String, dynamic>;
    }

    final plain = await booked(quoteWith(null, null));
    expect(plain.containsKey('transport_number'), isFalse);
    expect(plain.containsKey('sign_name'), isFalse);
    final toStation = await booked(quoteWith(null, 'station'));
    expect(toStation, containsPair('transport_number', 'TGV 6543'));
    expect(toStation.containsKey('sign_name'), isFalse);
    expect(await booked(quoteWith(null, 'station'), roundTrip: true), containsPair('sign_name', 'Léa Morel'));
  });

  test('sans compte : le compte est créé avec le formulaire, puis la course est réservée', () async {
    final booking = controller((request) async => switch (request.url.path) {
          '/api/v1/quotes' => json(quoteBody),
          '/api/v1/profile' => json({'user': {'first_name': 'Paul', 'last_name': 'Roux', 'email': 'paul@example.com', 'phone': '0612345678'}}),
          _ => json({'reference': 'GSV-abc', 'status': 'pending', 'payment_status': 'awaiting_payment', 'pickup_address': 'Aéroport de Genève',
              'destination_address': 'Annecy, France', 'departure_at': '2026-11-03T11:00:00Z', 'quoted_price': '44.0', 'amount_due': '44.0'}, 201),
        }, signedIn: false);
    await booking.showPrices();
    booking
      ..toCustomer()
      ..firstName = 'Paul'
      ..lastName = 'Roux'
      ..email = 'paul@example.com'
      ..phone = '0612345678'
      ..termsAccepted = true;
    var created = 0;
    await booking.confirm(signedIn: false, createAccount: () async => created++);
    expect(created, 1);
    expect(booking.step, BookingStep.done);
    expect(sent.map((r) => r.url.path), contains('/api/v1/bookings'));
  });

  test('sans compte : un e-mail déjà connu demande de se connecter, sans réserver', () async {
    final booking = controller((_) async => json(quoteBody), signedIn: false);
    await booking.showPrices();
    booking
      ..toCustomer()
      ..firstName = 'Claire'
      ..lastName = 'Dupont'
      ..email = 'claire@example.com'
      ..phone = '0612345678'
      ..termsAccepted = true;
    await booking.confirm(signedIn: false, createAccount: () async => throw ApiException('Un compte existe déjà.', status: 409, code: 'email_taken'));
    expect(booking.accountExists, isTrue);
    expect(booking.error, contains('connectez-vous'));
    expect(booking.step, BookingStep.customer);
    expect(sent.where((r) => r.url.path == '/api/v1/bookings'), isEmpty);
  });

  test('sans compte, les prix et adresses se demandent sans jeton', () async {
    final booking = controller((_) async => json(quoteBody), signedIn: false);
    await booking.showPrices();
    expect(sent.single.headers.containsKey('Authorization'), isFalse);
  });
}
