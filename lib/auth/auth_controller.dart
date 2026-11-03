import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../api/api_client.dart';
import '../config.dart';
import 'session_store.dart';

enum AuthState { unknown, signedOut, signedIn }

// Compte du client : facultatif pour voir les prix, obligatoire pour réserver.
// Connexion par e-mail, par Google (prénom, nom et e-mail repris du compte Google) ou création de compte.
class AuthController extends ChangeNotifier {
  AuthController({required this.client, required this.store, this.platform = 'android'});

  final ApiClient client;
  final SessionStore store;
  final String platform;

  AuthState state = AuthState.unknown;
  bool _googleReady = false;

  bool get googleAvailable => googleServerClientId.isNotEmpty;

  Future<void> restore() async {
    state = await store.read() == null ? AuthState.signedOut : AuthState.signedIn;
    notifyListeners();
  }

  Future<void> loginWithEmail(String email, String password) =>
      _open('/api/v1/mobile/sessions', {'email': email.trim(), 'password': password});

  Future<void> register({required String firstName, required String lastName, required String email, required String phone, required String password}) =>
      _open('/api/v1/mobile/registration', {'first_name': firstName.trim(), 'last_name': lastName.trim(), 'email': email.trim(), 'phone': phone.trim(), 'password': password});

  // « Continuer avec Google » : le jeton d'identité Google est vérifié par l'API, qui ouvre ou crée le compte client.
  // Renvoie false si le client a fermé la fenêtre Google.
  Future<bool> loginWithGoogle() async {
    if (!googleAvailable) throw ApiException('La connexion Google n’est pas encore disponible dans cette version.');
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize(serverClientId: googleServerClientId);
      _googleReady = true;
    }
    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return false;
      throw ApiException('Connexion Google impossible : ${error.description ?? error.code.name}.');
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) throw ApiException('Google n’a pas renvoyé d’identité. Réessayez.');
    await _open('/api/v1/mobile/google_session', {'id_token': idToken});
    return true;
  }

  Future<void> _open(String path, Map<String, dynamic> body) async {
    await client.openSession(path, {...body, 'platform': platform, 'device_name': 'Android'});
    state = AuthState.signedIn;
    notifyListeners();
  }

  // Ferme la session de cet appareil ; le site et les autres appareils restent connectés.
  Future<void> logout() async {
    final session = await store.read();
    if (session != null) {
      try {
        await client.delete('/api/v1/mobile/sessions/${session.sessionId}');
      } on ApiException {
        // Déjà fermée côté serveur.
      }
    }
    if (_googleReady) await GoogleSignIn.instance.signOut();
    await store.clear();
    expired();
  }

  void expired() {
    state = AuthState.signedOut;
    notifyListeners();
  }
}
