// ============================================================
// MON CAR PRO — Supervision des plantages : Crashlytics + Sentry.
//
// Crashlytics (Firebase, projet mon-car-a5a97) sur Android / iOS.
// Sentry seulement si un DSN est fourni à la compilation
// (MONCAR_SENTRY_DSN, secret de CI) — sinon désactivé.
// Aucune donnée personnelle envoyée : pas d'IP, pas de nom, pas de numéro.
// ============================================================

library;

import 'dart:async';

import 'package:core_api/core_api.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../firebase_options.dart';

bool _crashlyticsReady = false;

/// Initialise Firebase Crashlytics puis lance [appRunner] sous Sentry.
Future<void> runMonitored(FutureOr<void> Function() appRunner) async {
  if (DefaultFirebaseOptions.isSupported) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final crashlytics = FirebaseCrashlytics.instance;
    // Pas de remontée depuis les postes de développement (mode debug).
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
    await crashlytics.setCustomKey('env', AppEnvironment.current.name);
    FlutterError.onError = crashlytics.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
    _crashlyticsReady = true;
  }

  if (AppEnvironment.sentryDsn.isEmpty) {
    await appRunner();
    return;
  }
  // Sentry chaîne les gestionnaires d'erreurs déjà posés (Crashlytics) :
  // chaque plantage part vers les deux outils.
  await SentryFlutter.init((options) {
    options.dsn = AppEnvironment.sentryDsn;
    options.environment = AppEnvironment.current.name;
    options.sendDefaultPii = false;
  }, appRunner: appRunner);
  Sentry.configureScope((scope) => scope.setTag('app', 'pro'));
}

/// Étiquette les rapports avec le poste actif (contrôleur, convoyeur…),
/// pour trier les plantages par profil (roadmap Sprint 1).
void setMonitoringProfile(String? profile) {
  final value = profile ?? 'aucun';
  if (_crashlyticsReady) {
    FirebaseCrashlytics.instance.setCustomKey('profil', value);
  }
  if (Sentry.isEnabled) {
    Sentry.configureScope((scope) => scope.setTag('profil', value));
  }
}
