import 'package:geolocator/geolocator.dart';

// Position du téléphone, pour proposer l'adresse de départ ("Utiliser ma position"). Le système demande d'abord
// l'accord du client ; la position sert seulement à trouver l'adresse la plus proche (API) et n'est pas enregistrée.
enum LocationFailure { serviceDisabled, denied, deniedForever, unavailable }

class LocationException implements Exception {
  const LocationException(this.reason);

  final LocationFailure reason;

  String get message => switch (reason) {
        LocationFailure.serviceDisabled => 'La localisation du téléphone est désactivée. Activez-la, ou saisissez l\'adresse de départ.',
        LocationFailure.denied => 'Position refusée : saisissez l\'adresse de départ.',
        LocationFailure.deniedForever => 'La position est bloquée pour TonVTC. Autorisez-la dans les réglages du téléphone, ou saisissez l\'adresse.',
        LocationFailure.unavailable => 'Position indisponible pour le moment. Saisissez l\'adresse de départ.',
      };
}

abstract class DeviceLocator {
  Future<({double lat, double lng})> current();
  Future<void> openSettings();
}

class GeolocatorLocator implements DeviceLocator {
  const GeolocatorLocator();

  @override
  Future<({double lat, double lng})> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) throw const LocationException(LocationFailure.serviceDisabled);
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) throw const LocationException(LocationFailure.denied);
    if (permission == LocationPermission.deniedForever) throw const LocationException(LocationFailure.deniedForever);
    try {
      final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)));
      return (lat: position.latitude, lng: position.longitude);
    } catch (_) {
      throw const LocationException(LocationFailure.unavailable);
    }
  }

  @override
  Future<void> openSettings() => Geolocator.openAppSettings();
}
