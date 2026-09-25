# Environnements de compilation (dev · recette · prod)

Roadmap Sprint 1 : l'environnement est choisi **à la compilation** et n'est pas
modifiable depuis l'app.

| Fichier | `MONCAR_ENV` | Flavor Android | Nom affiché |
|---|---|---|---|
| `dev.json` | `dev` | `dev` (par défaut) | MON CAR Dev / MON CAR PRO Dev |
| `recette.json` | `recette` | `recette` | MON CAR Recette / MON CAR PRO Recette |
| `prod.json` | `prod` | `prod` | MON CAR / MON CAR PRO |

Clés lues par `AppEnvironment` (`packages/core_api`) :

- `MONCAR_ENV` — `dev`, `recette` ou `prod` ;
- `MONCAR_API_BASE_URL` — URL de l'API (`https://…/api/v1`). **Vide** tant que
  Richard n'a pas publié l'API de l'environnement : les apps restent alors sur
  leurs données de démonstration ;
- `MONCAR_SENTRY_DSN` — **jamais dans ces fichiers** : passé par la CI
  (secret GitHub `SENTRY_DSN_MOBILE`) avec `--dart-define`.

## Commandes (depuis `apps/client` ou `apps/pro`)

```bash
flutter run --flavor dev --dart-define-from-file=../../config/dev.json
flutter build apk --debug --flavor dev --dart-define-from-file=../../config/dev.json
flutter build appbundle --flavor prod --dart-define-from-file=../../config/prod.json
```

`flutter run` sans `--flavor` lance la variante `dev` (`default-flavor` dans
le pubspec de chaque app). Penser à ajouter `--dart-define-from-file`, sinon
les valeurs par défaut s’appliquent (environnement dev, pas d’API, pas de Sentry).

## Limites connues

- **Même identifiant d'application pour les trois variantes** : la
  configuration Firebase (`google-services.json`) ne connaît que
  `com.moncar.moncar_client` et `com.moncar.moncar_pro`. On ne peut donc pas
  installer dev et prod côte à côte sur un téléphone. Pour le permettre, il
  faudra enregistrer des apps `.dev` / `.recette` dans Firebase puis ajouter
  `applicationIdSuffix`.
- **iOS** : les schémas Xcode `dev` / `recette` / `prod` restent à créer sur
  un Mac. En attendant, lancer iOS **sans** `--flavor`, avec seulement
  `--dart-define-from-file`.
