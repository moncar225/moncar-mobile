# MON CAR — Mobile (monorepo Flutter)

Espace de travail mobile du projet MON CAR (transport · colis · location de véhicules).
Le **backend (Symfony/API) est un dépôt séparé — `moncar-api` — et n'est jamais modifié ici.**
Le projet web React vivra dans un dépôt séparé `moncar-web`.

## Structure

```
apps/
├── client/      App passager (Voyager · Colis · Location)
└── pro/         App professionnelle (compagnies, agences, propriétaires, VTC, admin)

packages/
├── core_api/    Client HTTP centralisé + gestion commune des erreurs (dio)
├── core_data/   Cache hors-ligne Drift (schéma à venir, lié au contrat OpenAPI)
├── core_ui/     Design System MON CAR (tokens, thème, composants de base)
├── core_qr/     Scanner QR (billets, colis) via mobile_scanner
└── core_geo/    Cartographie (flutter_map) pour suivi voyage/colis
```

## Stack

Flutter 3.44 · Dart 3.12 · Riverpod · go_router · Drift · mobile_scanner · flutter_map · Melos + pub workspace.

## Commandes

```bash
dart pub get              # résout tout le workspace (une seule fois, à la racine)
dart run melos run analyze
dart run melos run test
dart run melos run gen    # génération de code (Drift) quand le schéma sera défini
```

## Environnements (dev · recette · prod)

Flavors Android `dev` / `recette` / `prod` + `--dart-define-from-file=../../config/<env>.json`.
Détails, commandes et limites : [`config/README.md`](config/README.md).

## Supervision des plantages

- **Crashlytics** (Firebase, projet `mon-car-a5a97`) dans les deux apps ;
  désactivé en mode debug dans l'app PRO.
- **Sentry** dans les deux apps, actif seulement si `MONCAR_SENTRY_DSN` est
  fourni à la compilation (secret CI `SENTRY_DSN_MOBILE`). Aucune donnée
  personnelle envoyée. Étiquettes : `app`, `env`, et `profil` pour l'app PRO.

## Galerie du design system

Écran `/galerie` dans les deux apps (dev et recette uniquement) : couleurs,
typographie, composants, états et messages d'erreur API. Accès : Profil
(app PRO) ou Paramètres › À propos (app client).

## Intégration continue

`.github/workflows/mobile.yml` : format, `flutter analyze` (zéro remarque) et
tests à chaque PR ; APK debug `dev` des deux apps en artefacts sur `main`.
Secret GitHub facultatif : `SENTRY_DSN_MOBILE`.

## Règles projet (rappel)

- Backend = source de vérité. Aucun endpoint inventé : les chemins d'API
  proviennent du contrat OpenAPI. Toute info manquante est signalée, jamais supposée.
- Les composants UI passent par `core_ui` ; les appels API passent par `core_api`.
- Erreurs API normalisées en français (401/403/404/409/422/429/500 + réseau).
- Pas de secrets dans le code ; pas de données fictives dans les écrans finaux.
