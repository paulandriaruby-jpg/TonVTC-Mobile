import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Jetons de la session, rangés dans le coffre sécurisé du téléphone (Keystore Android / Trousseau iOS).
class StoredSession {
  const StoredSession({required this.token, required this.refreshToken, required this.sessionId});

  final String token;
  final String refreshToken;
  final int sessionId;
}

abstract class SessionStore {
  Future<StoredSession?> read();
  Future<void> write(StoredSession session);
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<StoredSession?> read() async {
    final token = await _storage.read(key: 'token');
    final refreshToken = await _storage.read(key: 'refresh_token');
    final sessionId = int.tryParse(await _storage.read(key: 'session_id') ?? '');
    if (token == null || refreshToken == null || sessionId == null) return null;
    return StoredSession(token: token, refreshToken: refreshToken, sessionId: sessionId);
  }

  @override
  Future<void> write(StoredSession session) async {
    await _storage.write(key: 'token', value: session.token);
    await _storage.write(key: 'refresh_token', value: session.refreshToken);
    await _storage.write(key: 'session_id', value: '${session.sessionId}');
  }

  @override
  Future<void> clear() => _storage.deleteAll();
}

// Pour les tests : en mémoire.
class MemorySessionStore implements SessionStore {
  StoredSession? value;

  @override
  Future<StoredSession?> read() async => value;

  @override
  Future<void> write(StoredSession session) async => value = session;

  @override
  Future<void> clear() async => value = null;
}
