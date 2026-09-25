// ============================================================
// MON CAR PRO — Politique de collecte GPS du chauffeur (GPS-001).
//
// Fréquence adaptative : rapprochée en ville et à l'approche d'un arrêt,
// espacée sur la route. ⚠️ Valeurs de travail : la fréquence définitive et
// les objectifs batterie / données sont à arbitrer (T-5) — tout est
// paramétré ici, rien n'est dispersé dans les écrans.
// ============================================================

library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ModeGps {
  /// Ville ou approche d'arrêt : précision et fréquence élevées.
  rapproche('Rapprochée'),

  /// Route entre deux arrêts : économie de batterie et de données.
  route('Route');

  const ModeGps(this.libelle);
  final String libelle;
}

@immutable
class PolitiqueGps {
  const PolitiqueGps({
    this.seuilApprocheKm = 3,
    this.vitesseVilleKmh = 40,
    this.intervalleRapproche = const Duration(seconds: 10),
    this.distanceRapprocheM = 20,
    this.intervalleRoute = const Duration(seconds: 30),
    this.distanceRouteM = 150,
    this.tailleLot = 10,
  });

  /// En deçà de cette distance du prochain arrêt : mode rapproché.
  final double seuilApprocheKm;

  /// En dessous de cette vitesse (circulation urbaine) : mode rapproché.
  final double vitesseVilleKmh;
  final Duration intervalleRapproche;
  final int distanceRapprocheM;
  final Duration intervalleRoute;
  final int distanceRouteM;

  /// Positions regroupées par envoi (POST /pro/positions).
  final int tailleLot;

  static const defaut = PolitiqueGps();

  ModeGps modePour({double? distanceProchainArretKm, double vitesseKmh = 0}) {
    if (distanceProchainArretKm != null &&
        distanceProchainArretKm <= seuilApprocheKm) {
      return ModeGps.rapproche;
    }
    if (vitesseKmh > 0 && vitesseKmh < vitesseVilleKmh) {
      return ModeGps.rapproche;
    }
    return ModeGps.route;
  }

  Duration intervalle(ModeGps mode) =>
      mode == ModeGps.rapproche ? intervalleRapproche : intervalleRoute;

  int distanceMin(ModeGps mode) =>
      mode == ModeGps.rapproche ? distanceRapprocheM : distanceRouteM;

  /// Réglages plateforme : service de premier plan Android (notification
  /// permanente, suivi écran éteint) et mode arrière-plan iOS — seulement
  /// pendant le voyage actif.
  LocationSettings reglages(ModeGps mode) {
    final precision = mode == ModeGps.rapproche
        ? LocationAccuracy.best
        : LocationAccuracy.high;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: precision,
        distanceFilter: distanceMin(mode),
        intervalDuration: intervalle(mode),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Voyage en cours',
          notificationText:
              'MON CAR PRO partage votre position avec la compagnie.',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: precision,
        distanceFilter: distanceMin(mode),
        activityType: ActivityType.automotiveNavigation,
        allowBackgroundLocationUpdates: true,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
    return LocationSettings(
      accuracy: precision,
      distanceFilter: distanceMin(mode),
    );
  }
}

/// Position collectée : heure terrain (appareil), distincte de l'heure
/// serveur, et précision, pour l'ingestion par lots (GPS-001).
@immutable
class PointGps {
  const PointGps({
    required this.lat,
    required this.lng,
    required this.horodatage,
    this.precisionM = 0,
    this.vitesseKmh = 0,
  });

  final double lat;
  final double lng;
  final DateTime horodatage;
  final double precisionM;
  final double vitesseKmh;

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
    't': horodatage.toIso8601String(),
    'p': precisionM,
    'v': vitesseKmh,
  };

  static PointGps fromJson(Map<String, dynamic> j) => PointGps(
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    horodatage: DateTime.parse(j['t'] as String),
    precisionM: (j['p'] as num?)?.toDouble() ?? 0,
    vitesseKmh: (j['v'] as num?)?.toDouble() ?? 0,
  );
}

/// Tampon local des positions non envoyées : survit à une coupure réseau
/// et à un redémarrage de l'app (reprise d'état). ⚠️ Préférences en
/// attendant le schéma Drift de core_data.
class TamponPositions {
  TamponPositions(this._prefs);

  static const _cle = 'pro.gps.tampon';
  final SharedPreferences? _prefs;

  List<PointGps> lire() {
    final brut = _prefs?.getString(_cle);
    if (brut == null) return const [];
    try {
      return (jsonDecode(brut) as List)
          .map((e) => PointGps.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  List<PointGps> ajouter(PointGps p) {
    final points = [...lire(), p];
    _ecrire(points);
    return points;
  }

  /// Retire et renvoie un lot complet s'il est atteint.
  List<PointGps>? extraireLot(int taille) {
    final points = lire();
    if (points.length < taille) return null;
    _ecrire(points.sublist(taille));
    return points.sublist(0, taille);
  }

  void vider() => _prefs?.remove(_cle);

  void _ecrire(List<PointGps> points) => _prefs?.setString(
    _cle,
    jsonEncode(points.map((p) => p.toJson()).toList()),
  );
}
