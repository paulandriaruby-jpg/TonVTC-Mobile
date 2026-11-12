import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/session_store.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.status, this.code});

  final String message;
  final int? status;
  final String? code;

  @override
  String toString() => message;
}

// Session perdue (jeton de renouvellement expiré ou refusé) : l'app revient à l'écran de connexion.
class SessionExpired extends ApiException {
  SessionExpired() : super('Session expirée : reconnectez-vous.', status: 401, code: 'session_expired');
}

// Client de l'API : ajoute le jeton d'accès, et sur un 401 le renouvelle une fois avec le jeton de 30 jours avant de
// rejouer la requête (le jeton d'accès ne vaut que 12 h, ou a été révoqué par une déconnexion du site).
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

  // Envoi d'un fichier (pièce justificative) : formulaire multipart, avec le même renouvellement de session.
  Future<dynamic> upload(String path, {required Map<String, String> fields, required String fileField, required List<int> bytes, required String filename}) async {
    Future<http.Response> attempt(StoredSession session) async {
      final request = http.MultipartRequest('POST', _uri(path))
        ..headers.addAll({'Accept': 'application/json', 'Authorization': 'Bearer ${session.token}'})
        ..fields.addAll(fields)
        ..files.add(http.MultipartFile.fromBytes(fileField, bytes, filename: filename));
      return http.Response.fromStream(await _http.send(request));
    }

    final session = await store.read();
    if (session == null) throw SessionExpired();
    var response = await attempt(session);
    if (response.statusCode == 401) {
      final renewed = await _refresh(session);
      if (renewed == null) throw SessionExpired();
      response = await attempt(renewed);
    }
    return _decode(response);
  }

  // Connexion : pas de jeton à envoyer, la réponse ouvre la session.
  Future<Map<String, dynamic>> login({required String email, required String password, required Map<String, String?> device}) async {
    final response = await _http.post(_uri('/api/v1/mobile/sessions'), headers: _headers(null),
        body: jsonEncode({'email': email, 'password': password, ...device}));
    final data = _decode(response) as Map<String, dynamic>;
    await store.write(StoredSession(token: data['token'] as String, refreshToken: data['refresh_token'] as String, sessionId: data['session_id'] as int));
    return data;
  }

  Future<dynamic> _send(String method, String path, {Map<String, String>? query, Map<String, dynamic>? body, bool retried = false}) async {
    final session = await store.read();
    if (session == null) throw SessionExpired();
    final request = http.Request(method, _uri(path, query))..headers.addAll(_headers(session.token));
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(await _http.send(request));
    if (response.statusCode == 401 && !retried) {
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
