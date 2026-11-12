import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gs_vtc_client/api/api_client.dart';
import 'package:gs_vtc_client/api/client_api.dart';
import 'package:gs_vtc_client/auth/session_store.dart';
import 'package:gs_vtc_client/models/models.dart';
import 'package:gs_vtc_client/widgets/pay_button.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response json(Object body, [int status = 200]) => http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> ride(String status, String payment) => {
      'id': 7, 'reference': 'GSV-123456789012', 'status': status, 'payment_status': payment, 'pickup_address': 'Annecy',
      'destination_address': 'Aéroport de Genève', 'departure_at': '2026-12-01T09:00:00Z', 'quoted_price': '110.00', 'amount_due': '110.00',
    };

void main() {
  test('une course est à payer tant qu\'elle n\'est ni réglée, ni annulée, ni terminée', () {
    expect(Ride.fromJson(ride('pending', 'awaiting_payment')).needsPayment, isTrue);
    expect(Ride.fromJson(ride('pending', 'payment_failed')).needsPayment, isTrue);
    expect(Ride.fromJson(ride('pending', 'paid')).needsPayment, isFalse);
    expect(Ride.fromJson(ride('cancelled', 'awaiting_payment')).needsPayment, isFalse);
  });

  testWidgets('un appui ouvre la fenêtre de paiement Stripe puis confirme le paiement, sans quitter l\'app', (tester) async {
    final sent = <http.Request>[];
    var confirmations = 0;
    final store = MemorySessionStore()..value = const StoredSession(token: 't', refreshToken: 'r', sessionId: 1);
    final api = ClientApi(ApiClient(baseUrl: 'http://api', store: store, client: MockClient((request) async {
      sent.add(request);
      if (request.url.path == '/api/v1/payments') {
        return json({'client_secret': 'pi_1_secret_x', 'publishable_key': 'pk_test_x', 'merchant_name': 'TonVTC'}, 201);
      }
      confirmations++;
      return json({'payment_status': confirmations > 1 ? 'paid' : 'awaiting_payment'});
    })));
    PaymentSheetData? shown;
    var paid = false;

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: PayButton(
      api: api, reference: 'GSV-123456789012', amount: 110, onPaid: () => paid = true,
      present: (data) async { shown = data; return true; },
    )))));
    expect(find.textContaining('Payer 110,00'), findsOneWidget);

    await tester.tap(find.textContaining('Payer 110,00'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(shown?.clientSecret, 'pi_1_secret_x');
    expect(shown?.publishableKey, 'pk_test_x');
    expect(jsonDecode(sent.first.body), {'reference': 'GSV-123456789012', 'mode': 'sheet'});
    // La banque confirme au deuxième essai.
    expect(paid, isTrue);
    expect(sent.where((request) => request.url.path == '/api/v1/payments/confirm'), hasLength(2));
  });

  testWidgets('fenêtre fermée par le client : rien n\'est confirmé', (tester) async {
    final sent = <http.Request>[];
    final store = MemorySessionStore()..value = const StoredSession(token: 't', refreshToken: 'r', sessionId: 1);
    final api = ClientApi(ApiClient(baseUrl: 'http://api', store: store, client: MockClient((request) async {
      sent.add(request);
      return json({'client_secret': 'pi_1_secret_x', 'publishable_key': 'pk_test_x'}, 201);
    })));
    var paid = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: PayButton(
      api: api, reference: 'GSV-123456789012', amount: 110, onPaid: () => paid = true, present: (_) async => false,
    )))));
    await tester.tap(find.textContaining('Payer 110,00'));
    await tester.pumpAndSettle();
    expect(paid, isFalse);
    expect(sent, hasLength(1));
  });
}
