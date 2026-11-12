import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gs_vtc_driver/api/api_client.dart';
import 'package:gs_vtc_driver/api/driver_api.dart';
import 'package:gs_vtc_driver/auth/session_store.dart';
import 'package:gs_vtc_driver/models/models.dart';
import 'package:gs_vtc_driver/recruitment/document_picker.dart';
import 'package:gs_vtc_driver/widgets/driver_photo_card.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

class FakePicker implements DocumentPicker {
  PickSource? asked;

  @override
  Future<PickedDocument?> pick(PickSource source) async {
    asked = source;
    return const PickedDocument(bytes: [1, 2, 3], filename: 'selfie.jpg');
  }
}

void main() {
  test('lit la photo approuvée, en attente ou refusée', () {
    expect(DriverPhoto.fromJson({}).missing, isTrue);
    final pending = DriverPhoto.fromJson({'photo_url': '/a', 'pending_photo_url': '/b', 'photo_status': 'pending'});
    expect(pending.pending, isTrue);
    expect(pending.missing, isFalse);
    final rejected = DriverPhoto.fromJson({'photo_status': 'rejected', 'photo_rejection_reason': 'Visage caché'});
    expect(rejected.rejected, isTrue);
    expect(rejected.missing, isTrue);
  });

  testWidgets('prend un selfie, l\'envoie et annonce la vérification', (tester) async {
    final sent = <http.BaseRequest>[];
    DriverPhoto? changed;
    final picker = FakePicker();
    final client = ApiClient(
      baseUrl: 'http://api',
      store: MemorySessionStore()..value = const StoredSession(token: 't', refreshToken: 'r', sessionId: 1),
      client: MockClient((request) async {
        sent.add(request);
        return http.Response(jsonEncode({'photo_url': null, 'pending_photo_url': '/api/v1/driver_photos/x', 'photo_status': 'pending'}), 201,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );
    await tester.pumpWidget(MultiProvider(
      providers: [Provider.value(value: DriverApi(client)), Provider<DocumentPicker>.value(value: picker)],
      child: MaterialApp(home: Scaffold(body: DriverPhotoCard(photo: DriverPhoto.fromJson({}), onChanged: (photo) => changed = photo))),
    ));
    expect(find.text('Ajoutez votre photo'), findsOneWidget);

    await tester.tap(find.text('Ajouter ma photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prendre un selfie'));
    await tester.pumpAndSettle();

    expect(picker.asked, PickSource.selfie);
    expect(sent.single.url.path, '/api/v1/profile/photo');
    expect(changed?.pending, isTrue);
    expect(find.textContaining('l\'équipe la vérifie'), findsOneWidget);
  });
}
