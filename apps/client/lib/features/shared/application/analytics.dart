// ============================================================
// MON CAR — Mesure d'audience (Firebase Analytics).
// Le backend Symfony reste la source de vérité métier :
// Analytics ne mesure que le parcours dans l'appli (écrans vus,
// funnel de réservation) ; les plantages passent par Crashlytics.
// ============================================================

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/widgets.dart';

/// Pont vers Firebase Analytics, coupable d'un seul geste.
/// `enabled = false` dans les tests, où aucun plugin natif Firebase
/// n'est disponible (même garde que `NetworkMonitor.enabled`).
class MoncarAnalytics {
  MoncarAnalytics._();

  static bool enabled = true;

  static FirebaseAnalytics? _instance;

  /// Instance Firebase Analytics, `null` quand désactivée.
  static FirebaseAnalytics? get instance {
    if (!enabled) return null;
    return _instance ??= FirebaseAnalytics.instance;
  }

  /// À brancher sur le GoRouter (`observers:`) pour tracer chaque vue
  /// d'écran. Le nom remonté est le `name` de la GoRoute si défini,
  /// sinon son chemin complet (avec IDs dynamiques) — d'où les noms
  /// explicites donnés dans router.dart.
  static NavigatorObserver? get screenObserver {
    final analytics = instance;
    if (analytics == null) return null;
    return FirebaseAnalyticsObserver(analytics: analytics);
  }
}
