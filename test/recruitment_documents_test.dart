import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gs_vtc_driver/api/api_client.dart';
import 'package:gs_vtc_driver/api/driver_api.dart';
import 'package:gs_vtc_driver/auth/session_store.dart';
import 'package:gs_vtc_driver/models/models.dart';
import 'package:gs_vtc_driver/recruitment/document_picker.dart';
import 'package:gs_vtc_driver/recruitment/recruitment.dart';
import 'package:gs_vtc_driver/screens/recruitment_documents_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

class FakePicker implements DocumentPicker {
  PickSource? asked;

  @override
  Future<PickedDocument?> pick(PickSource source) async {
    asked = source;
    return const PickedDocument(bytes: [1, 2, 3], filename: 'permis.jpg');
  }
}

http.Response json(Object body, [int status = 200]) => http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> profileJson({List<Map<String, dynamic>> documents = const [], List<String> missing = const ['identity', 'driving_license', 'vtc_card'], bool locked = false, String legal = 'self_employed'}) => {
      'user': {'first_name': 'Alice', 'last_name': 'Martin', 'email': 'alice@example.com'},
      'driver': {
        'validation_status': 'data_collected',
        'locked': locked,
        'legal_status': legal,
        'details_missing': <String>[],
        'documents_missing': missing,
        'documents': documents,
      },
    };

void main() {
  test('envoi de fichier : formulaire multipart, rejoué après un renouvellement de session', () async {
    final store = MemorySessionStore()..value = const StoredSession(token: 'old', refreshToken: 'r1', sessionId: 1);
    final calls = <String>[];
    final client = ApiClient(baseUrl: 'http://api', store: store, client: MockClient((request) async {
      calls.add('${request.method} ${request.url.path} ${request.headers['Authorization'] ?? ''}');
      if (request.url.path.endsWith('/refresh')) return json({'token': 'new', 'refresh_token': 'r2', 'session_id': 1});
      if (request.headers['Authorization'] != 'Bearer new') return json({'error': {'code': 'unauthorized'}}, 401);
      expect(request.headers['content-type'], startsWith('multipart/form-data'));
      expect(request.body, allOf(contains('name="kind"'), contains('driving_license'), contains('filename="permis.jpg"')));
      return json({'id': 9}, 201);
    }));
    await DriverApi(client).uploadDocument(kind: 'driving_license', bytes: [1, 2, 3], filename: 'permis.jpg');
    expect(calls, ['POST /api/v1/profile/documents Bearer old', 'POST /api/v1/mobile/sessions/refresh ', 'POST /api/v1/profile/documents Bearer new']);
  });

  test('pièces demandées : le Kbis seulement hors auto-entrepreneur', () {
    expect(personalDocuments('self_employed').map((d) => d.kind), ['identity', 'driving_license', 'vtc_card']);
    expect(personalDocuments('company').map((d) => d.kind), ['identity', 'driving_license', 'vtc_card', 'company_registration']);
    expect(fileSize(2048), '2 Ko');
    expect(fileSize(1572864), '1,5 Mo');
  });

  Future<({List<http.Request> sent, FakePicker picker})> pump(WidgetTester tester, Map<String, dynamic> profile, {Map<String, dynamic>? afterUpload}) async {
    final sent = <http.Request>[];
    final picker = FakePicker();
    var current = profile;
    final client = ApiClient(
      baseUrl: 'http://api',
      store: MemorySessionStore()..value = const StoredSession(token: 't', refreshToken: 'r', sessionId: 1),
      client: MockClient((request) async {
        sent.add(request);
        if (request.method == 'POST') {
          current = afterUpload ?? current;
          return json({'id': 5}, 201);
        }
        if (request.method == 'DELETE') {
          current = profileJson();
          return http.Response('', 204);
        }
        return json(current);
      }),
    );
    await tester.binding.setSurfaceSize(const Size(420, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MultiProvider(
      providers: [Provider.value(value: DriverApi(client)), Provider<DocumentPicker>.value(value: picker)],
      child: MaterialApp(home: RecruitmentDocumentsScreen(profile: DriverProfile.fromJson(profile))),
    ));
    return (sent: sent, picker: picker);
  }

  testWidgets('ajoute une photo, puis la pièce passe à "Reçu" et le fichier apparaît', (tester) async {
    final doc = {'id': 5, 'kind': 'driving_license', 'filename': 'permis.jpg', 'byte_size': 204800};
    final env = await pump(tester, profileJson(), afterUpload: profileJson(documents: [doc], missing: ['identity', 'vtc_card']));
    expect(find.text('À fournir'), findsNWidgets(3));

    await tester.tap(find.text('Ajouter').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prendre une photo'));
    await tester.pumpAndSettle();

    expect(env.picker.asked, PickSource.camera);
    expect(env.sent.map((r) => '${r.method} ${r.url.path}'), ['POST /api/v1/profile/documents', 'GET /api/v1/profile']);
    expect(find.text('permis.jpg'), findsOneWidget);
    expect(find.text('200 Ko'), findsOneWidget);
    expect(find.text('Reçu'), findsOneWidget);
    expect(find.text('Ajouter le verso'), findsOneWidget);
  });

  testWidgets('supprime un fichier après confirmation', (tester) async {
    final doc = {'id': 5, 'kind': 'driving_license', 'filename': 'permis.jpg', 'byte_size': 204800};
    final env = await pump(tester, profileJson(documents: [doc], missing: ['identity', 'vtc_card']));
    await tester.tap(find.byTooltip('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(env.sent.map((r) => '${r.method} ${r.url.path}'), ['DELETE /api/v1/profile/documents/5', 'GET /api/v1/profile']);
    expect(find.text('permis.jpg'), findsNothing);
  });

  testWidgets('société : le Kbis est demandé', (tester) async {
    await pump(tester, profileJson(legal: 'company', missing: ['company_registration']));
    expect(find.text('Extrait Kbis'), findsOneWidget);
  });

  testWidgets('dossier figé : aucun ajout possible', (tester) async {
    await pump(tester, profileJson(locked: true, missing: []));
    expect(find.textContaining('ne sont plus modifiables'), findsOneWidget);
    expect(find.text('Ajouter'), findsNothing);
    expect(find.textContaining('Enregistrer'), findsNothing);
  });

  testWidgets('enregistre le numéro de carte VTC et le type de pièce', (tester) async {
    final env = await pump(tester, profileJson());
    await tester.enterText(find.byType(TextField).first, 'VTC-0123');
    await tester.scrollUntilVisible(find.text('Enregistrer les numéros et dates'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Enregistrer les numéros et dates'));
    await tester.pumpAndSettle();
    final request = env.sent.single;
    expect('${request.method} ${request.url.path}', 'PATCH /api/v1/profile');
    expect(jsonDecode(request.body), containsPair('vtc_card_number', 'VTC-0123'));
  });
}
