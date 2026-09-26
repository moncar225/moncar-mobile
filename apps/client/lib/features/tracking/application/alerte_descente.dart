// ============================================================
// MON CAR — Alerte de descente (CDC §17, GPS-002).
//
// En production, la détection d'approche est faite par le SERVEUR à partir
// du GPS réel du car, puis poussée (notification prioritaire + Mercure).
// ⚠️ MOCK : sans API, l'état est calculé ici à partir des positions
// simulées du suivi — même règle : environ 1 km, puis arrivée.
// ============================================================

library;

import 'dart:math' as math;

import 'package:flutter_tts/flutter_tts.dart';

import '../../shared/domain/models.dart';

enum EtapeDescente {
  /// Le car est encore loin de l'arrêt du passager.
  enRoute,

  /// Environ 1 km avant l'arrêt : « Préparez-vous à descendre ».
  proche,

  /// Le car est à l'arrêt du passager.
  arrive,
}

/// Messages exacts du cahier des charges.
const messageProche = 'Votre arrêt approche. Préparez-vous à descendre.';
const messageArrivee =
    'Vous êtes arrivé à votre arrêt. Veuillez préparer votre descente.';

/// Distance à vol d'oiseau (km).
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a.toDouble()));
}

/// Étape de l'alerte pour l'arrêt [indexArret] du passager.
///
/// « Proche » dès que le car roule vers cet arrêt et en est à ~1 km (ou à
/// 2 minutes, les positions n'arrivant que par intervalles) ; « arrivé »
/// dès que l'arrêt est atteint.
EtapeDescente etapeDescente({
  required BusPosition bus,
  required List<Stop> arrets,
  required int indexArret,
  double seuilKm = 1.0,
}) {
  if (indexArret < 0 || indexArret >= arrets.length) {
    return EtapeDescente.enRoute;
  }
  if (bus.state == TrackingState.termine ||
      bus.currentStopIndex >= indexArret) {
    return EtapeDescente.arrive;
  }
  final cible = arrets[indexArret];
  if (bus.nextStopId != cible.id) return EtapeDescente.enRoute;
  final restant = distanceKm(
    bus.latitude,
    bus.longitude,
    cible.latitude,
    cible.longitude,
  );
  if (restant <= seuilKm || bus.etaToNextStopMin <= 2) {
    return EtapeDescente.proche;
  }
  return EtapeDescente.enRoute;
}

/// Annonce vocale (option du CDC). Sans effet si le moteur est indisponible.
class AnnonceVocale {
  FlutterTts? _tts;

  Future<void> dire(String texte) async {
    try {
      final tts = _tts ??= FlutterTts();
      await tts.setLanguage('fr-FR');
      await tts.setSpeechRate(0.5);
      await tts.speak(texte);
    } catch (_) {
      // L'alerte visuelle et la vibration suffisent.
    }
  }
}
