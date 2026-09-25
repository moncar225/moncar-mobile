// ============================================================
// MON CAR PRO — Suivi GPS du chauffeur + alertes vocales.
//
// Côté app : collecte des positions pendant le voyage actif, stockage
// local et envoi par lots (POST /pro/positions). Le calcul d'ETA et la
// détection d'approche sont serveur (GPS-001/002) : ici, ⚠️ MOCK, une
// simulation le long de l'axe pilote tient lieu de flux serveur.
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

class GpsController extends Notifier<GpsState> {
  Timer? _timer;
  final _rng = math.Random();
  bool _announced1km = false;
  bool _announcedArrival = false;
  String? _segmentKey;

  /// Pas de simulation (km par seconde) — accéléré pour la démonstration.
  static const _kmPerTick = 1.6;
  static const _batchSize = 10;

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
    return GpsState(lat: s.lat, lng: s.lng);
  }

  void _sync(DriverPhase phase) {
    if (state.deviceGps) return;
    final moving = phase == DriverPhase.enRoute && state.tracking;
    if (moving && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } else if (!moving) {
      _timer?.cancel();
      _timer = null;
      final trip = ref.read(tripProvider);
      if (phase != DriverPhase.enRoute) {
        final s = trip.voyage.currentStop;
        state = GpsState(
          lat: s.lat,
          lng: s.lng,
          tracking: state.tracking,
          bufferedPoints: state.bufferedPoints,
          sentBatches: state.sentBatches,
          accuracyM: state.accuracyM,
        );
      }
    }
  }

  void setTracking(bool on) {
    state = state.copyWith(tracking: on);
    _sync(ref.read(tripProvider).phase);
  }

  StreamSubscription<Position>? _device;

  /// Bascule sur le GPS réel du téléphone (hors simulation de démo).
  /// Renvoie un message d'erreur si la localisation est refusée.
  Future<String?> useDeviceGps(bool on) async {
    await _device?.cancel();
    _device = null;
    if (!on) {
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
      _timer?.cancel();
      _timer = null;
      state = state.copyWith(deviceGps: true);
      _device =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 25,
            ),
          ).listen((p) {
            final buffered = state.bufferedPoints + 1;
            final flush = buffered >= _batchSize;
            if (flush) {
              ref
                  .read(syncProvider.notifier)
                  .enqueue('POSITIONS', 'Lot de $buffered positions GPS');
            }
            state = state.copyWith(
              lat: p.latitude,
              lng: p.longitude,
              speedKmh: math.max(0, p.speed * 3.6),
              accuracyM: p.accuracy,
              bufferedPoints: flush ? 0 : buffered,
              sentBatches: flush ? state.sentBatches + 1 : null,
            );
          }, onError: (Object _) {});
      return null;
    } catch (_) {
      return 'GPS indisponible sur cet appareil.';
    }
  }

  void _tick() {
    final trip = ref.read(tripProvider);
    final next = trip.voyage.nextStop;
    if (next == null) return;
    final key = '${trip.voyage.currentStopIndex}';
    if (_segmentKey != key) {
      _segmentKey = key;
      _announced1km = false;
      _announcedArrival = false;
    }
    final dist = haversineKm(state.lat, state.lng, next.lat, next.lng);
    final step = math.min(_kmPerTick, dist);
    final f = dist == 0 ? 1.0 : step / dist;
    final lat = state.lat + (next.lat - state.lat) * f;
    final lng = state.lng + (next.lng - state.lng) * f;
    final remaining = math.max(0.0, dist - step);
    final buffered = state.bufferedPoints + 1;
    var batches = state.sentBatches;
    var bufferAfter = buffered;
    if (buffered >= _batchSize) {
      // Envoi par lots (heure terrain + identifiant appareil côté serveur).
      ref
          .read(syncProvider.notifier)
          .enqueue('POSITIONS', 'Lot de $buffered positions GPS');
      batches++;
      bufferAfter = 0;
    }
    state = state.copyWith(
      lat: lat,
      lng: lng,
      speedKmh: remaining < 2
          ? 32 + _rng.nextInt(12).toDouble()
          : 78 + _rng.nextInt(18).toDouble(),
      distanceToNextKm: remaining,
      bufferedPoints: bufferAfter,
      sentBatches: batches,
    );

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
