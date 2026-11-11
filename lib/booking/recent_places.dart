import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/models.dart';

// Dernières adresses choisies (5 au plus), gardées sur le téléphone pour les retrouver en un geste dans la recherche.
// Une erreur de stockage n'empêche jamais de réserver : la liste est simplement vide.
class RecentPlaces {
  RecentPlaces([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'recent_places';
  static const max = 5;
  final FlutterSecureStorage _storage;

  Future<List<Place>> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return [];
      return (jsonDecode(raw) as List).map((item) => Place.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> add(Place place) async {
    try {
      final list = [place, ...(await load()).where((item) => item.placeId != place.placeId)].take(max).toList();
      await _storage.write(key: _key, value: jsonEncode(list.map((item) => item.toJson()).toList()));
    } catch (_) {
      // Sans stockage : pas d'adresses récentes.
    }
  }

  // Compte supprimé : les adresses récentes ne restent pas sur le téléphone.
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // Rien à effacer.
    }
  }
}
