import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import 'session_store.dart';

enum AuthState { unknown, signedOut, signedIn }

// Connexion du chauffeur : restaure la session au démarrage, ouvre une session par appareil, la ferme.
class AuthController extends ChangeNotifier {
  AuthController({required this.client, required this.store, this.deviceName = 'Android', this.platform = 'android'});

  final ApiClient client;
  final SessionStore store;
  final String deviceName;
  final String platform;

  AuthState state = AuthState.unknown;
  String? firstName;

  Future<void> restore() async {
    state = await store.read() == null ? AuthState.signedOut : AuthState.signedIn;
    notifyListeners();
  }

  Future<void> login(String email, String password, {String? pushToken}) async {
    final data = await client.login(email: email.trim(), password: password,
        device: {'device_name': deviceName, 'platform': platform, 'push_token': pushToken});
    firstName = (data['user'] as Map<String, dynamic>?)?['first_name'] as String?;
    state = AuthState.signedIn;
    notifyListeners();
  }

  // Ferme la session de cet appareil (plus de notifications ici) ; le site et les autres appareils restent connectés.
  Future<void> logout() async {
    final session = await store.read();
    if (session != null) {
      try {
        await client.delete('/api/v1/mobile/sessions/${session.sessionId}');
      } on ApiException {
        // Déjà fermée côté serveur : on oublie la session locale de toute façon.
      }
    }
    await store.clear();
    expired();
  }

  // Appelé quand le renouvellement échoue : retour à l'écran de connexion.
  void expired() {
    state = AuthState.signedOut;
    firstName = null;
    notifyListeners();
  }
}
