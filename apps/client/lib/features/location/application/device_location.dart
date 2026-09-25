// ============================================================
// MON CAR — Position de l'appareil (module Location, §26).
//
// À l'ouverture du parcours « Louer un véhicule », la position du
// client est proposée comme point de prise en charge. La position GPS
// est rapprochée de la localité connue la plus proche (liste des
// villes) — aucun service de géocodage externe n'est appelé.
// ============================================================

import 'package:geolocator/geolocator.dart';

import '../../shared/foundation.dart';

class DeviceLocation {
  DeviceLocation._();

  /// Désactivé dans les tests widget (pas de plugin natif) — même garde
  /// que `MoncarPhoneAuth.enabled`.
  static bool enabled = true;

  /// Localité la plus proche de la position actuelle, ou un message
  /// d'erreur compréhensible (service coupé, permission refusée…).
  static Future<({City? city, String? error})> nearestCity(
    List<City> cities,
  ) async {
    if (!enabled) {
      return (city: null, error: 'Localisation indisponible sur cet appareil.');
    }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return (
          city: null,
          error: 'Activez la localisation de votre téléphone.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return (
          city: null,
          error: 'Autorisez MON CAR à utiliser votre position.',
        );
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      City? best;
      var bestDistance = double.infinity;
      for (final c in cities) {
        final d = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          c.latitude,
          c.longitude,
        );
        if (d < bestDistance) {
          bestDistance = d;
          best = c;
        }
      }
      return (city: best, error: best == null ? 'Position inconnue.' : null);
    } catch (_) {
      return (city: null, error: 'Position introuvable. Réessayez.');
    }
  }
}
