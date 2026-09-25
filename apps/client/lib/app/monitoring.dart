// ============================================================
// MON CAR — Supervision des plantages : Crashlytics + Sentry.
//
// Crashlytics (Firebase, projet mon-car-a5a97) est initialisé dans main.dart.
// Sentry seulement si un DSN est fourni à la compilation
// (MONCAR_SENTRY_DSN, secret de CI) — sinon désactivé.
// Aucune donnée personnelle envoyée : pas d'IP, pas de nom, pas de numéro.
// ============================================================

library;

import 'dart:async';

import 'package:core_api/core_api.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Lance [appRunner] sous Sentry (chaîné aux gestionnaires Crashlytics déjà
/// posés : chaque plantage part vers les deux outils).
Future<void> runMonitored(FutureOr<void> Function() appRunner) async {
  if (AppEnvironment.sentryDsn.isEmpty) {
    await appRunner();
    return;
  }
  await SentryFlutter.init((options) {
    options.dsn = AppEnvironment.sentryDsn;
    options.environment = AppEnvironment.current.name;
    options.sendDefaultPii = false;
  }, appRunner: appRunner);
  Sentry.configureScope((scope) => scope.setTag('app', 'client'));
}
