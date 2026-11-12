import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gs_vtc_client/api/api_client.dart';
import 'package:gs_vtc_client/api/client_api.dart';
import 'package:gs_vtc_client/auth/session_store.dart';
import 'package:gs_vtc_client/location/device_location.dart';
import 'package:gs_vtc_client/models/models.dart';
import 'package:gs_vtc_client/screens/address_search_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

class FakeLocator implements DeviceLocator {
  FakeLocator({this.failure});

  final LocationFailure? failure;
  int asked = 0;

  @override
  Future<({double lat, double lng})> current() async {
    asked++;
    if (failure != null) throw LocationException(failure!);
    return (lat: 46.1442, lng: 6.0817);
  }

  @override
  Future<void> openSettings() async {}
}

void main() {
  late List<http.Request> sent;

  ClientApi api() {
    sent = [];
    return ClientApi(ApiClient(baseUrl: 'http://api', store: MemorySessionStore(), client: MockClient((request) async {
      sent.add(request);
      return http.Response(jsonEncode({'place_id': 'ChIJstreet', 'address': '6 Pl. du Général de Gaulle, 74160 Saint-Julien-en-Genevois, France', 'lat': 46.1442, 'lng': 6.0817}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    })));
  }

  // Ouvre la recherche d'adresse depuis un écran parent (elle se referme sur le lieu choisi).
  Future<void> open(WidgetTester tester, FakeLocator locator, {bool withLocation = true}) async {
    await tester.pumpWidget(Provider.value(
      value: api(),
      child: MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(
        onPressed: () => Navigator.of(context).push<Place>(MaterialPageRoute(builder: (_) => AddressSearchScreen(title: 'Adresse de départ', withLocation: withLocation, locator: locator))),
        child: const Text('ouvrir'),
      )))),
    ));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('"Utiliser ma position" renvoie l\'adresse la plus proche du téléphone', (tester) async {
    final locator = FakeLocator();
    await open(tester, locator);
    expect(find.text('Utiliser ma position'), findsOneWidget);
    await tester.tap(find.text('Utiliser ma position'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(locator.asked, 1);
    expect(sent.single.url.path, '/api/v1/places/reverse');
    expect(sent.single.url.queryParameters, {'lat': '46.1442', 'lng': '6.0817'});
    expect(find.text('Utiliser ma position'), findsNothing, reason: 'l\'écran se referme sur l\'adresse trouvée');
  });

  testWidgets('un refus de position est expliqué, sans appel à l\'API', (tester) async {
    final locator = FakeLocator(failure: LocationFailure.denied);
    await open(tester, locator);
    await tester.tap(find.text('Utiliser ma position'));
    await tester.pumpAndSettle();
    expect(find.text('Position refusée : saisissez l\'adresse de départ.'), findsOneWidget);
    expect(sent, isEmpty);
  });

  testWidgets('pas de position proposée pour l\'adresse d\'arrivée', (tester) async {
    await open(tester, FakeLocator(), withLocation: false);
    expect(find.text('Utiliser ma position'), findsNothing);
  });
}
