import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gs_vtc_driver/api/api_client.dart';
import 'package:gs_vtc_driver/api/driver_api.dart';
import 'package:gs_vtc_driver/auth/session_store.dart';
import 'package:gs_vtc_driver/models/models.dart';
import 'package:gs_vtc_driver/recruitment/recruitment.dart';
import 'package:gs_vtc_driver/screens/recruitment_details_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

Map<String, dynamic> profileJson({String status = 'identified', bool locked = false, Map<String, dynamic> driver = const {}}) => {
      'user': {'first_name': 'Alice', 'last_name': 'Martin', 'email': 'alice@example.com'},
      'driver': {'validation_status': status, 'locked': locked, 'details_missing': <String>[], 'documents_missing': <String>[], ...driver},
    };

String? check({String legal = 'self_employed', String address = '1 rue A', String postcode = '73000', String city = 'Chambéry', String iban = 'FR7630006000011234567890189', String siret = '73282932000074', String name = '', String rcs = '', String capital = ''}) =>
    detailsError(legalStatus: legal, address: address, postcode: postcode, city: city, iban: iban, siret: siret, businessName: name, rcsCode: rcs, shareCapital: capital);

void main() {
  test('contrôles du formulaire : adresse, SIRET, IBAN, et société hors auto-entrepreneur', () {
    expect(check(), isNull);
    expect(check(address: ' '), 'Indiquez votre adresse complète.');
    expect(check(postcode: '7'), 'Code postal invalide.');
    expect(check(siret: '7328 293'), 'Le SIRET contient 14 chiffres.');
    expect(check(siret: '732 829 320 00074'), isNull);
    expect(check(iban: 'FR76'), 'Indiquez votre IBAN.');
    expect(check(legal: 'company'), 'Indiquez le nom de la société et la ville du RCS.');
    expect(check(legal: 'company', name: 'Alpes VTC', rcs: 'Chambéry'), 'Indiquez le capital social.');
    expect(check(legal: 'company', name: 'Alpes VTC', rcs: 'Chambéry', capital: '1000,50'), isNull);
  });

  test('profil : les informations déjà saisies sont reprises', () {
    final details = DriverProfile.fromJson(profileJson(driver: {'legal_status': 'company', 'city': 'Annecy', 'share_capital': '1500.0'})).details;
    expect(details.legalStatus, 'company');
    expect(details.city, 'Annecy');
    expect(details.shareCapital, '1500.0');
    expect(DriverProfile.fromJson(profileJson()).details.legalStatus, 'self_employed');
  });

  Future<List<http.Request>> pump(WidgetTester tester, DriverProfile profile, {http.Response Function(http.Request)? reply}) async {
    final sent = <http.Request>[];
    final client = ApiClient(
      baseUrl: 'http://api',
      store: MemorySessionStore()..value = const StoredSession(token: 't', refreshToken: 'r', sessionId: 1),
      client: MockClient((request) async {
        sent.add(request);
        return (reply ?? (_) => http.Response(jsonEncode(profileJson(status: 'data_collected')), 200, headers: {'content-type': 'application/json; charset=utf-8'}))(request);
      }),
    );
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(Provider.value(value: DriverApi(client), child: MaterialApp(home: RecruitmentDetailsScreen(profile: profile))));
    return sent;
  }

  testWidgets('enregistre les informations d\'un auto-entrepreneur', (tester) async {
    final sent = await pump(tester, DriverProfile.fromJson(profileJson()));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '732 829 320 00074');
    await tester.enterText(fields.at(1), '1 rue des Alpes');
    await tester.enterText(fields.at(2), '73000');
    await tester.enterText(fields.at(3), 'Chambéry');
    await tester.enterText(fields.at(4), 'FR76 3000 6000 0112 3456 7890 189');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final request = sent.single;
    expect('${request.method} ${request.url.path}', 'PATCH /api/v1/profile');
    expect(jsonDecode(request.body), containsPair('siret', '73282932000074'));
    expect(jsonDecode(request.body), containsPair('legal_status', 'self_employed'));
    expect(jsonDecode(request.body), containsPair('business_name', ''));
    expect(jsonDecode(request.body)['share_capital'], isNull);
  });

  testWidgets('affiche le refus du serveur et n\'envoie rien si le formulaire est incomplet', (tester) async {
    final sent = await pump(tester, DriverProfile.fromJson(profileJson()), reply: (_) => http.Response(jsonEncode({'error': {'code': 'invalid_profile', 'message': 'Iban n\'est pas valide'}}), 422, headers: {'content-type': 'application/json; charset=utf-8'}));
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    expect(find.text('Indiquez votre adresse complète.'), findsOneWidget);
    expect(sent, isEmpty);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '73282932000074');
    await tester.enterText(fields.at(1), '1 rue des Alpes');
    await tester.enterText(fields.at(2), '73000');
    await tester.enterText(fields.at(3), 'Chambéry');
    await tester.enterText(fields.at(4), 'FR7630006000011234567890188');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Iban n\'est pas valide'), findsOneWidget);
  });

  testWidgets('dossier relu par l\'équipe : lecture seule, sans bouton', (tester) async {
    await pump(tester, DriverProfile.fromJson(profileJson(status: 'files_collected', locked: true)));
    expect(find.textContaining('ne sont plus modifiables'), findsOneWidget);
    expect(find.text('Enregistrer'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField).first).enabled, isFalse);
  });

  testWidgets('société : les champs RCS et capital apparaissent', (tester) async {
    await pump(tester, DriverProfile.fromJson(profileJson(driver: {'legal_status': 'company'})));
    expect(find.text('Nom de la société'), findsOneWidget);
    expect(find.text('Ville du RCS'), findsOneWidget);
    expect(find.text('Capital social (€)'), findsOneWidget);
  });
}
