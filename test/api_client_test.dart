import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gs_vtc_driver/api/api_client.dart';
import 'package:gs_vtc_driver/auth/session_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late MemorySessionStore store;

  setUp(() => store = MemorySessionStore()..value = const StoredSession(token: 'old', refreshToken: 'refresh-1', sessionId: 7));

  http.Response json(Object body, int status) => http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

  test('renouvelle le jeton une fois sur un 401 puis rejoue la requête', () async {
    final calls = <String>[];
    final client = ApiClient(baseUrl: 'http://api', store: store, client: MockClient((request) async {
      calls.add('${request.method} ${request.url.path} ${request.headers['Authorization'] ?? ''}');
      if (request.url.path == '/api/v1/mobile/sessions/refresh') {
        expect(jsonDecode(request.body), {'refresh_token': 'refresh-1'});
        return json({'token': 'new', 'refresh_token': 'refresh-2', 'session_id': 7}, 200);
      }
      return request.headers['Authorization'] == 'Bearer new' ? json({'ok': true}, 200) : json({'error': {'code': 'unauthorized'}}, 401);
    }));

    expect(await client.get('/api/v1/earnings'), {'ok': true});
    expect(calls, ['GET /api/v1/earnings Bearer old', 'POST /api/v1/mobile/sessions/refresh ', 'GET /api/v1/earnings Bearer new']);
    expect(store.value?.refreshToken, 'refresh-2');
  });

  test('session expirée : jetons effacés et erreur dédiée', () async {
    final client = ApiClient(baseUrl: 'http://api', store: store, client: MockClient((request) async => json({'error': {'code': 'invalid_refresh_token'}}, 401)));
    await expectLater(client.get('/api/v1/proposals'), throwsA(isA<SessionExpired>()));
    expect(store.value, isNull);
  });

  test('un seul renouvellement pour plusieurs requêtes refusées en même temps', () async {
    var refreshes = 0;
    final client = ApiClient(baseUrl: 'http://api', store: store, client: MockClient((request) async {
      if (request.url.path.endsWith('/refresh')) {
        refreshes++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return json({'token': 'new', 'refresh_token': 'refresh-2', 'session_id': 7}, 200);
      }
      return request.headers['Authorization'] == 'Bearer new' ? json([], 200) : json({}, 401);
    }));
    await Future.wait([client.get('/a'), client.get('/b'), client.get('/c')]);
    expect(refreshes, 1);
  });

  test('message de l’API repris dans l’erreur, connexion qui enregistre la session', () async {
    final client = ApiClient(baseUrl: 'http://api', store: MemorySessionStore(), client: MockClient((request) async {
      if (request.url.path == '/api/v1/mobile/sessions') {
        return json({'token': 't', 'refresh_token': 'r', 'session_id': 3, 'user': {'first_name': 'Alice'}}, 201);
      }
      return json({'error': {'code': 'unavailable', 'message': 'Cette proposition n’est plus disponible.'}}, 409);
    }));
    final data = await client.login(email: 'a@b.fr', password: 'x', device: {'platform': 'android'});
    expect(data['session_id'], 3);
    expect((client.store as MemorySessionStore).value?.token, 't');
    await expectLater(client.post('/api/v1/proposals/1/accept'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 409).having((e) => e.message, 'message', 'Cette proposition n’est plus disponible.')));
  });
}
