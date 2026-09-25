// ============================================================
// MON CAR PRO — Providers transverses (stockage, API, réseau, thème).
// ============================================================

library;

import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/pro_api.dart';

/// Préférences locales, injectées dans `main()`. `null` dans les tests :
/// l'état reste alors en mémoire.
final sharedPrefsProvider = Provider<SharedPreferences?>((ref) => null);

/// Client API. ⚠️ MOCK tant que le contrat OpenAPI n'est pas gelé.
final proApiProvider = Provider<ProApi>(
  (ref) => MockProApi(prefs: ref.watch(sharedPrefsProvider)),
);

/// Données de démonstration visibles (scans simulés, astuces de test).
/// À désactiver lors du branchement sur l'API réelle.
const kDemoMode = true;

final _random = Random.secure();

/// Clé d'idempotence (UUID v4) pour les opérations sensibles.
String newIdempotencyKey() {
  final b = List<int>.generate(16, (_) => _random.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

// ----------------------------- Réseau -----------------------------

@immutable
class NetworkState {
  const NetworkState({this.deviceOnline = true, this.forcedOffline = false});

  /// Réseau détecté par le téléphone.
  final bool deviceOnline;

  /// Mode hors ligne forcé (essais terrain / recette en « mode avion »).
  final bool forcedOffline;

  bool get online => deviceOnline && !forcedOffline;
}

class NetworkController extends Notifier<NetworkState> {
  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  NetworkState build() {
    ref.onDispose(() => _sub?.cancel());
    _watch();
    return const NetworkState();
  }

  void _watch() {
    try {
      final c = Connectivity();
      c.checkConnectivity().then(_apply).catchError((Object _) {});
      _sub = c.onConnectivityChanged.listen(_apply, onError: (Object _) {});
    } catch (_) {
      // Plugin indisponible (tests) : on reste « en ligne ».
    }
  }

  void _apply(List<ConnectivityResult> r) {
    final online = r.any((x) => x != ConnectivityResult.none);
    state = NetworkState(
      deviceOnline: online,
      forcedOffline: state.forcedOffline,
    );
  }

  void setForcedOffline(bool value) {
    state = NetworkState(
      deviceOnline: state.deviceOnline,
      forcedOffline: value,
    );
  }
}

final networkProvider = NotifierProvider<NetworkController, NetworkState>(
  NetworkController.new,
);

// ----------------------------- Préférences -----------------------------

enum ThemeChoice {
  systeme('Système'),
  clair('Clair'),
  sombre('Sombre');

  const ThemeChoice(this.label);
  final String label;
}

@immutable
class ProSettings {
  const ProSettings({
    this.theme = ThemeChoice.systeme,
    this.voiceAlerts = true,
    this.haptics = true,
  });

  final ThemeChoice theme;

  /// Alertes vocales du chauffeur (« Arrêt à 1 km »…).
  final bool voiceAlerts;
  final bool haptics;

  ProSettings copyWith({
    ThemeChoice? theme,
    bool? voiceAlerts,
    bool? haptics,
  }) => ProSettings(
    theme: theme ?? this.theme,
    voiceAlerts: voiceAlerts ?? this.voiceAlerts,
    haptics: haptics ?? this.haptics,
  );
}

class SettingsController extends Notifier<ProSettings> {
  static const _kTheme = 'pro.settings.theme';
  static const _kVoice = 'pro.settings.voice';
  static const _kHaptics = 'pro.settings.haptics';

  SharedPreferences? get _prefs => ref.read(sharedPrefsProvider);

  @override
  ProSettings build() {
    final p = _prefs;
    if (p == null) return const ProSettings();
    return ProSettings(
      theme:
          ThemeChoice.values.asNameMap()[p.getString(_kTheme)] ??
          ThemeChoice.systeme,
      voiceAlerts: p.getBool(_kVoice) ?? true,
      haptics: p.getBool(_kHaptics) ?? true,
    );
  }

  void setTheme(ThemeChoice t) {
    state = state.copyWith(theme: t);
    _prefs?.setString(_kTheme, t.name);
  }

  void setVoiceAlerts(bool v) {
    state = state.copyWith(voiceAlerts: v);
    _prefs?.setBool(_kVoice, v);
  }

  void setHaptics(bool v) {
    state = state.copyWith(haptics: v);
    _prefs?.setBool(_kHaptics, v);
  }
}

final settingsProvider = NotifierProvider<SettingsController, ProSettings>(
  SettingsController.new,
);
