import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/session_store.dart';
import '../config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.status, this.code});

  final String message;
  final int? status;
  final String? code;

  @override
  String toString() => message;
}

// Session perdue (jeton de renouvellement expiré ou refusé) : le client doit se reconnecter.
class SessionExpired extends ApiException {
  SessionExpired() : super('Session expirée : reconnectez-vous.', status: 401, code: 'session_expired');
}

// Client de l'API. Sans session, les requêtes partent sans jeton (prix, adresses : pas besoin de compte) ;
// avec une session, un 401 déclenche un renouvellement unique (jeton de 30 jours) puis la requête est rejouée.
class ApiClient {
  ApiClient({required this.baseUrl, required this.store, http.Client? client}) : _http = client ?? http.Client();

  final String baseUrl;
  final SessionStore store;
  final http.Client _http;
  Future<StoredSession?>? _refreshing;

  Future<dynamic> get(String path, {Map<String, String>? query}) => _send('GET', path, query: query);
  Future<dynamic> post(String path, [Map<String, dynamic>? body]) => _send('POST', path, body: body);
  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) => _send('PATCH', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  // Connexion (e-mail, Google ou création de compte) : la réponse ouvre la session de l'appareil.
  Future<Map<String, dynamic>> openSession(String path, Map<String, dynamic> body) async {
    final response = await _http.post(_uri(path), headers: _headers(null), body: jsonEncode({'app': 'client', ...body}));
    final data = _decode(response) as Map<String, dynamic>;
    await store.write(StoredSession(token: data['token'] as String, refreshToken: data['refresh_token'] as String, sessionId: data['session_id'] as int));
    return data;
  }

  Future<dynamic> _send(String method, String path, {Map<String, String>? query, Map<String, dynamic>? body, bool retried = false}) async {
    final session = await store.read();
    final request = http.Request(method, _uri(path, query))..headers.addAll(_headers(session?.token));
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(await _http.send(request));
    if (response.statusCode == 401 && session != null && !retried) {
      final renewed = await _refresh(session);
      if (renewed == null) throw SessionExpired();
      return _send(method, path, query: query, body: body, retried: true);
    }
    return _decode(response);
  }

  // Un seul renouvellement à la fois, même si plusieurs requêtes reçoivent un 401 en même temps.
  Future<StoredSession?> _refresh(StoredSession session) {
    return _refreshing ??= () async {
      try {
        final response = await _http.post(_uri('/api/v1/mobile/sessions/refresh'), headers: _headers(null),
            body: jsonEncode({'refresh_token': session.refreshToken}));
        if (response.statusCode != 200) {
          await store.clear();
          return null;
        }
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final renewed = StoredSession(token: data['token'] as String, refreshToken: data['refresh_token'] as String, sessionId: data['session_id'] as int);
        await store.write(renewed);
        return renewed;
      } finally {
        _refreshing = null;
      }
    }();
  }

  Uri _uri(String path, [Map<String, String>? query]) => Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (stagingToken.isNotEmpty) 'X-Staging-Token': stagingToken,
        if (token != null) 'Authorization': 'Bearer $token',
      };

  dynamic _decode(http.Response response) {
    final body = response.body.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    final error = body is Map<String, dynamic> ? body['error'] : null;
    final message = error is Map<String, dynamic> ? error['message'] as String? : null;
    throw ApiException(message ?? 'Une erreur est survenue (${response.statusCode}).', status: response.statusCode,
        code: error is Map<String, dynamic> ? error['code'] as String? : null);
  }
}
