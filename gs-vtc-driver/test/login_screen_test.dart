import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gs_vtc_driver/api/api_client.dart';
import 'package:gs_vtc_driver/api/driver_api.dart';
import 'package:gs_vtc_driver/auth/auth_controller.dart';
import 'package:gs_vtc_driver/auth/session_store.dart';
import 'package:gs_vtc_driver/push/push_service.dart';
import 'package:gs_vtc_driver/screens/login_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

void main() {
  Future<AuthController> pump(WidgetTester tester, MockClient http) async {
    final store = MemorySessionStore();
    final client = ApiClient(baseUrl: 'http://api', store: store, client: http);
    final auth = AuthController(client: client, store: store);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        Provider.value(value: DriverApi(client)),
        Provider.value(value: PushService(client: client, store: store)),
      ],
      child: const MaterialApp(home: LoginScreen()),
    ));
    return auth;
  }

  testWidgets('affiche le refus de l\'API et ne connecte pas', (tester) async {
    final auth = await pump(tester, MockClient((_) async => http.Response(
        jsonEncode({'error': {'code': 'drivers_only', 'message': 'L\'application est réservée aux chauffeurs partenaires.'}}), 403,
        headers: {'content-type': 'application/json; charset=utf-8'})));
    await tester.enterText(find.byType(TextFormField).at(0), 'client@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret');
    // Le bouton est sous la photo : on fait défiler jusqu'à lui.
    await tester.ensureVisible(find.text('Se connecter'));
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(find.text('L\'application est réservée aux chauffeurs partenaires.'), findsOneWidget);
    expect(auth.state, isNot(AuthState.signedIn));
  });

  testWidgets('connecte le chauffeur avec ses identifiants', (tester) async {
    late Map<String, dynamic> sent;
    final auth = await pump(tester, MockClient((request) async {
      sent = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(jsonEncode({'token': 't', 'refresh_token': 'r', 'session_id': 1, 'user': {'first_name': 'Alice'}}), 201);
    }));
    await tester.enterText(find.byType(TextFormField).at(0), ' alice@example.com ');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret');
    // Le bouton est sous la photo : on fait défiler jusqu'à lui.
    await tester.ensureVisible(find.text('Se connecter'));
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(sent, containsPair('email', 'alice@example.com'));
    expect(sent, containsPair('platform', 'android'));
    expect(auth.state, AuthState.signedIn);
    expect(auth.firstName, 'Alice');
  });

  testWidgets('reprend la page de connexion du site', (tester) async {
    await pump(tester, MockClient((_) async => http.Response('{}', 200)));
    expect(find.text('Heureux de vous retrouver'), findsOneWidget);
    expect(find.text('Mot de passe oublié ?'), findsOneWidget);
    expect(find.textContaining('Devenir chauffeur'), findsOneWidget);
    expect(find.text('Connexion sécurisée'), findsOneWidget);
  });
}
