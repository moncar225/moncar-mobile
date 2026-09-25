/// Environnement de compilation (dev, recette, prod) des apps MON CAR.
///
/// Les valeurs sont figées à la compilation par
/// `--dart-define-from-file=config/<env>.json` (voir `config/README.md`) :
/// elles ne sont pas modifiables depuis l'app (roadmap, Sprint 1).
library;

enum MoncarEnv {
  dev('Développement'),
  recette('Recette'),
  prod('Production');

  const MoncarEnv(this.label);

  /// Libellé français affiché (écran « À propos », bandeau d'environnement).
  final String label;
}

abstract final class AppEnvironment {
  static const String _name = String.fromEnvironment(
    'MONCAR_ENV',
    defaultValue: 'dev',
  );

  /// URL de base de l'API (`https://…/api/v1`). Vide tant que l'API de
  /// l'environnement n'est pas déployée : les apps restent alors sur leurs
  /// données de démonstration.
  static const String apiBaseUrl = String.fromEnvironment(
    'MONCAR_API_BASE_URL',
  );

  /// DSN Sentry. Vide = Sentry désactivé (poste de dev, tests). Fourni en CI
  /// par un secret GitHub, jamais écrit dans le dépôt.
  static const String sentryDsn = String.fromEnvironment('MONCAR_SENTRY_DSN');

  /// Environnement courant ; une valeur inconnue retombe sur [MoncarEnv.dev].
  static MoncarEnv get current => MoncarEnv.values.firstWhere(
    (e) => e.name == _name,
    orElse: () => MoncarEnv.dev,
  );

  static bool get isProd => current == MoncarEnv.prod;

  static bool get hasApi => apiBaseUrl.isNotEmpty;
}
