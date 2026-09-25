// ============================================================
// MON CAR PRO — Suivi GPS du chauffeur + alertes vocales.
//
// Côté app (GPS-001, VOY-003) : collecte des positions UNIQUEMENT pendant
// le voyage actif, en arrière-plan (service de premier plan Android, mode
// arrière-plan iOS), fréquence adaptative (voir gps_policy.dart, ⚠️ T-5),
// tampon local persistant et envoi par lots (POST /pro/positions).
// Le calcul d'ETA et la détection d'approche sont serveur : l'annonce
// vocale locale n'est qu'un confort pour le chauffeur. ⚠️ MOCK : sans GPS
// réel, une simulation le long de l'axe pilote tient lieu de flux.
// ============================================================

library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/models.dart';
import 'app_providers.dart';
import 'gps_policy.dart';
import 'notifications_controller.dart';
import 'sync_controller.dart';
import 'trip_controller.dart';

@immutable
class GpsState {
  const GpsState({
    required this.lat,
    required this.lng,
    this.speedKmh = 0,
    this.tracking = true,
    this.distanceToNextKm,
    this.bufferedPoints = 0,
    this.sentBatches = 0,
    this.deviceGps = false,
    this.accuracyM = 6,
    this.mode = ModeGps.route,
    this.pointsCollectes = 0,
    this.fluxActif = false,
  });

  final double lat;
  final double lng;
  final double speedKmh;
  final bool tracking;

  /// `true` : positions du GPS réel ; `false` : simulation de démo.
  final bool deviceGps;
  final double accuracyM;

  /// Distance restante jusqu'au prochain arrêt (km).
  final double? distanceToNextKm;

  /// Positions stockées localement, pas encore envoyées.
  final int bufferedPoints;
  final int sentBatches;

  /// Fréquence de collecte en cours (adaptative).
  final ModeGps mode;

  /// Positions collectées depuis le lancement (mesure batterie / données).
  final int pointsCollectes;

  /// Flux GPS réel ouvert (voyage actif, y compris écran éteint).
  final bool fluxActif;

  GpsState copyWith({
    double? lat,
    double? lng,
    double? speedKmh,
    bool? tracking,
    double? distanceToNextKm,
    int? bufferedPoints,
    int? sentBatches,
    bool? deviceGps,
    double? accuracyM,
    ModeGps? mode,
    int? pointsCollectes,
    bool? fluxActif,
  }) => GpsState(
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    speedKmh: speedKmh ?? this.speedKmh,
    tracking: tracking ?? this.tracking,
    distanceToNextKm: distanceToNextKm ?? this.distanceToNextKm,
    bufferedPoints: bufferedPoints ?? this.bufferedPoints,
    sentBatches: sentBatches ?? this.sentBatches,
    deviceGps: deviceGps ?? this.deviceGps,
    accuracyM: accuracyM ?? this.accuracyM,
    mode: mode ?? this.mode,
    pointsCollectes: pointsCollectes ?? this.pointsCollectes,
    fluxActif: fluxActif ?? this.fluxActif,
  );
}

/// Distance à vol d'oiseau (km).
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
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

/// Le GPS ne tourne que pendant le voyage actif (règle GPS-001).
bool voyageActif(DriverPhase phase) =>
    phase == DriverPhase.enRoute || phase == DriverPhase.aLArret;

class GpsController extends Notifier<GpsState> {
  Timer? _timer;
  StreamSubscription<Position>? _device;
  final _rng = math.Random();
  bool _announced1km = false;
  bool _announcedArrival = false;
  String? _segmentKey;
  PolitiqueGps politique = PolitiqueGps.defaut;

  /// Pas de simulation (km par seconde) — accéléré pour la démonstration.
  static const _kmPerTick = 1.6;

  TamponPositions get _tampon => TamponPositions(ref.read(sharedPrefsProvider));

  @override
  GpsState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _device?.cancel();
    });
    ref.listen(tripProvider.select((t) => t.phase), (_, phase) => _sync(phase));
    final trip = ref.read(tripProvider);
    final s = trip.voyage.currentStop;
    scheduleMicrotask(() => _sync(trip.phase));
    // Reprise d'état : positions non envoyées avant une coupure.
    return GpsState(
      lat: s.lat,
      lng: s.lng,
      bufferedPoints: _tampon.lire().length,
    );
  }

  void _sync(DriverPhase phase) {
    final actif = voyageActif(phase) && state.tracking;
    if (state.deviceGps) {
      _timer?.cancel();
      _timer = null;
      if (actif && _device == null) {
        _ouvrirFlux(state.mode);
      } else if (!actif) {
        _fermerFlux();
      }
      return;
    }
    final moving = phase == DriverPhase.enRoute && state.tracking;
    if (moving && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } else if (!moving) {
      _timer?.cancel();
      _timer = null;
      final trip = ref.read(tripProvider);
      if (phase != DriverPhase.enRoute) {
        final s = trip.voyage.currentStop;
        state = state.copyWith(lat: s.lat, lng: s.lng, speedKmh: 0);
      }
    }
  }

  void setTracking(bool on) {
    state = state.copyWith(tracking: on);
    _sync(ref.read(tripProvider).phase);
  }

  /// Bascule sur le GPS réel du téléphone (hors simulation de démo).
  /// Renvoie un message d'erreur si la localisation est refusée.
  Future<String?> useDeviceGps(bool on) async {
    if (!on) {
      _fermerFlux();
      state = state.copyWith(deviceGps: false);
      _sync(ref.read(tripProvider).phase);
      return null;
    }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return 'Activez la localisation du téléphone.';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return 'Autorisation de localisation refusée.';
      }
      state = state.copyWith(deviceGps: true);
      _sync(ref.read(tripProvider).phase);
      return null;
    } catch (_) {
      return 'GPS indisponible sur cet appareil.';
    }
  }

  void _ouvrirFlux(ModeGps mode) {
    _device?.cancel();
    try {
      _device = Geolocator.getPositionStream(
        locationSettings: politique.reglages(mode),
      ).listen(_surPosition, onError: (Object _) {});
      state = state.copyWith(fluxActif: true, mode: mode);
    } catch (_) {
      _device = null;
      state = state.copyWith(fluxActif: false);
    }
  }

  void _fermerFlux() {
    _device?.cancel();
    _device = null;
    if (state.fluxActif) state = state.copyWith(fluxActif: false);
  }

  void _surPosition(Position p) {
    final next = ref.read(tripProvider).voyage.nextStop;
    final restant = next == null
        ? null
        : haversineKm(p.latitude, p.longitude, next.lat, next.lng);
    final vitesse = math.max(0, p.speed * 3.6).toDouble();
    _enregistrer(
      PointGps(
        lat: p.latitude,
        lng: p.longitude,
        horodatage: p.timestamp,
        precisionM: p.accuracy,
        vitesseKmh: vitesse,
      ),
      distanceToNextKm: restant,
    );
    if (next != null && restant != null) _verifierApproche(next, restant);
    // Fréquence adaptative : on rouvre le flux si le mode change.
    final mode = politique.modePour(
      distanceProchainArretKm: restant,
      vitesseKmh: vitesse,
    );
    if (mode != state.mode && _device != null) _ouvrirFlux(mode);
  }

  /// Tampon local puis envoi par lots (heure terrain + appareil côté serveur).
  void _enregistrer(PointGps point, {double? distanceToNextKm}) {
    final tampon = _tampon;
    tampon.ajouter(point);
    var lots = state.sentBatches;
    final lot = tampon.extraireLot(politique.tailleLot);
    if (lot != null) {
      ref
          .read(syncProvider.notifier)
          .enqueue('POSITIONS', 'Lot de ${lot.length} positions GPS');
      lots++;
    }
    state = state.copyWith(
      lat: point.lat,
      lng: point.lng,
      speedKmh: point.vitesseKmh,
      accuracyM: point.precisionM,
      distanceToNextKm: distanceToNextKm,
      bufferedPoints: tampon.lire().length,
      sentBatches: lots,
      pointsCollectes: state.pointsCollectes + 1,
    );
  }

  void _tick() {
    final trip = ref.read(tripProvider);
    final next = trip.voyage.nextStop;
    if (next == null) return;
    final dist = haversineKm(state.lat, state.lng, next.lat, next.lng);
    final step = math.min(_kmPerTick, dist);
    final f = dist == 0 ? 1.0 : step / dist;
    final lat = state.lat + (next.lat - state.lat) * f;
    final lng = state.lng + (next.lng - state.lng) * f;
    final remaining = math.max(0.0, dist - step);
    final vitesse = remaining < 2
        ? 32 + _rng.nextInt(12).toDouble()
        : 78 + _rng.nextInt(18).toDouble();
    _enregistrer(
      PointGps(
        lat: lat,
        lng: lng,
        horodatage: DateTime.now(),
        precisionM: 6,
        vitesseKmh: vitesse,
      ),
      distanceToNextKm: remaining,
    );
    state = state.copyWith(
      mode: politique.modePour(
        distanceProchainArretKm: remaining,
        vitesseKmh: vitesse,
      ),
    );
    _verifierApproche(next, remaining);
  }

  void _verifierApproche(Stop next, double remaining) {
    final key = '${ref.read(tripProvider).voyage.currentStopIndex}';
    if (_segmentKey != key) {
      _segmentKey = key;
      _announced1km = false;
      _announcedArrival = false;
    }
    if (!_announced1km && remaining <= 1.0 && remaining > 0.05) {
      _announced1km = true;
      _alert(
        'Arrêt ${next.shortName} dans 1 kilomètre.',
        'Arrêt à 1 km',
        '${next.name} — préparez l’arrêt.',
      );
    }
    if (!_announcedArrival && remaining <= 0.05) {
      _announcedArrival = true;
      _alert(
        'Vous êtes arrivé à ${next.shortName}. Confirmez l’arrivée à l’arrêt.',
        'Arrivée à l’arrêt',
        '${next.name} — confirmez l’arrivée.',
      );
    }
  }

  void _alert(String speech, String title, String body) {
    ref
        .read(notificationsProvider.notifier)
        .push(
          title,
          body,
          category: NotifCategory.alerte,
          route: '/chauf/actif',
        );
    if (ref.read(settingsProvider).voiceAlerts) {
      ref.read(voiceProvider).speak(speech);
    }
  }
}

final gpsProvider = NotifierProvider<GpsController, GpsState>(
  GpsController.new,
);

/// Synthèse vocale (alertes chauffeur). Sans effet si indisponible.
class VoiceService {
  FlutterTts? _tts;

  Future<void> speak(String text) async {
    try {
      final tts = _tts ??= FlutterTts();
      await tts.setLanguage('fr-FR');
      await tts.setSpeechRate(0.5);
      await tts.speak(text);
    } catch (_) {
      // Moteur vocal indisponible : l'alerte visuelle suffit.
    }
  }
}

final voiceProvider = Provider<VoiceService>((ref) => VoiceService());
