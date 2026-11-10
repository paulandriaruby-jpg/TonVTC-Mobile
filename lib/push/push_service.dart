import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../api/api_client.dart';
import '../auth/session_store.dart';

// Canaux Android : "Nouvelles courses" en priorité maximale (son, bandeau même téléphone verrouillé), "Rappels".
const newRidesChannel = AndroidNotificationChannel('new_rides', 'Nouvelles courses',
    description: 'Alerte dès qu\'une course vous est proposée', importance: Importance.max);
const remindersChannel = AndroidNotificationChannel('reminders', 'Rappels de course',
    description: 'Rappel la veille d\'une course', importance: Importance.high);

// Notifications de l'app : Firebase Cloud Messaging reçoit l'alerte (app fermée ou ouverte), on enregistre le jeton
// de l'appareil sur la session, et un appui sur la notification ouvre la course concernée.
// Sans configuration Firebase (google-services.json absent), l'app fonctionne sans notifications.
class PushService {
  PushService({required this.client, required this.store});

  final ApiClient client;
  final SessionStore store;
  final _local = FlutterLocalNotificationsPlugin();
  bool available = false;
  String? token;

  // Ouverture demandée par une notification : {type, booking_id, proposal_id}.
  final opened = ValueNotifier<Map<String, String>?>(null);

  Future<void> init() async {
    try {
      await Firebase.initializeApp();
    } catch (error) {
      debugPrint('Notifications désactivées (Firebase non configuré) : $error');
      return;
    }
    available = true;
    final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(newRidesChannel);
    await android?.createNotificationChannel(remindersChannel);
    await _local.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'), iOS: DarwinInitializationSettings()),
      onDidReceiveNotificationResponse: (response) => _open(response.payload),
    );

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, sound: true, badge: true);
    // Jeton d'appareil classique, celui qu'attend l'envoi par l'API (champ "token" de FCM HTTP v1). La nouvelle
    // inscription par identifiant d'installation (register / onRegistered) n'est pas encore utilisée côté serveur.
    // ignore: deprecated_member_use
    token = await messaging.getToken();
    // ignore: deprecated_member_use
    messaging.onTokenRefresh.listen((fresh) {
      token = fresh;
      registerToken();
    });
    // App au premier plan : Firebase n'affiche rien tout seul, on montre la notification nous-mêmes.
    FirebaseMessaging.onMessage.listen(_showForeground);
    FirebaseMessaging.onMessageOpenedApp.listen((message) => opened.value = _data(message));
    final initial = await messaging.getInitialMessage();
    if (initial != null) opened.value = _data(initial);
  }

  // Rattache le jeton de l'appareil à la session (après connexion, ou quand Firebase le change).
  Future<void> registerToken() async {
    final session = await store.read();
    if (token == null || session == null) return;
    try {
      await client.patch('/api/v1/mobile/sessions/${session.sessionId}', {'push_token': token, 'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'});
    } on ApiException catch (error) {
      debugPrint('Jeton de notification non enregistré : $error');
    }
  }

  void _showForeground(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    final channel = message.data['type'] == 'reminder' ? remindersChannel : newRidesChannel;
    _local.show(
      id: message.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(channel.id, channel.name, channelDescription: channel.description,
            importance: channel.importance, priority: Priority.high, category: AndroidNotificationCategory.message),
        iOS: const DarwinNotificationDetails(presentSound: true),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _open(String? payload) {
    if (payload == null) return;
    opened.value = (jsonDecode(payload) as Map<String, dynamic>).map((key, value) => MapEntry(key, '$value'));
  }

  Map<String, String> _data(RemoteMessage message) => message.data.map((key, value) => MapEntry(key, '$value'));
}
