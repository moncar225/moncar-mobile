import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';

/// Accès au capteur biométrique (empreinte, visage) via local_auth.
abstract final class Biometrics {
  static final _auth = LocalAuthentication();

  /// Au moins une biométrie est enrôlée et utilisable sur l'appareil.
  static Future<bool> available() async {
    if (kIsWeb) return false;
    try {
      if (!await _auth.isDeviceSupported()) return false;
      final types = await _auth.getAvailableBiometrics();
      return types.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Affiche l'invite système. `true` seulement si l'utilisateur est
  /// reconnu ; toute erreur (annulation, capteur bloqué…) renvoie `false`.
  static Future<bool> authenticate(String reason) async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }
}
