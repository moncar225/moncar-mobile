# MON CAR PRO — Rapport des changements et évolutions

Application mobile terrain `apps/pro` (Flutter) du monorepo MON CAR.
Ce fichier est tenu à jour à chaque évolution : ajouter une entrée datée
dans le **Journal** et mettre à jour les sections concernées.

- **Porteur** : PROSOFT ACADEMY
- **Interfaces** : Marcel (Flutter / React)
- **Documents de référence** :
  - Cahier des charges « PROJET DE DÉVELOPPEMENT DE LA PLATE-FORME MON CAR »
    (partie MON CAR PRO, postes 8 Contrôleur, 9 Convoyeur, 10 Chauffeur)
  - Roadmap de développement v1.0 du 18/09/2026 (§3.3, §9, §10.2, §13.5, §17)
- **Source portée** : prototype Next.js `Downloads/pro` (PWA mobile-first,
  3 postes terrain + écrans remise/restitution)

---

## 1. État actuel en bref

| Élément | État |
|---|---|
| Postes couverts | Contrôleur, Convoyeur, Chauffeur, Agent BUSINESS (remise/restitution) |
| Connexion / inscription | Parcours repris de l'app client (voir §3) |
| Données | ⚠️ Simulées (`MockProApi`) — contrat OpenAPI pas encore gelé |
| Hors ligne | File d'actions locale + synchronisation sans doublon |
| Qualité | `flutter analyze` : aucun problème · `flutter test` : 12 tests verts |
| Vérifié sur appareil réel | **Non** (caméra, GPS réel, voix, photos non essayés sur téléphone) |
| Commit Git | Aucun (modifications locales non commitées) |

---

## 2. Architecture

```
lib/
├── app/            app.dart (thème, langue), router.dart (routes + gardes), pro_shell.dart (barre de navigation par poste)
├── core/
│   ├── domain/     models.dart — postes, voyage, arrêts, passagers, scans, bagages, colis, incidents, locations, file de synchro
│   ├── data/       pro_api.dart (contrat + MockProApi), mock_data.dart (jeu de démo)
│   ├── application/ contrôleurs Riverpod : session, synchro, voyage, GPS + voix, location BUSINESS, notifications, réglages
│   └── ui/         kit terrain (cartes, KPI, « glisser pour confirmer »…), badges de statut, widgets voyage, formats FR
└── features/
    ├── auth/       onboarding, connexion, inscription, code SMS, mot de passe oublié / temporaire, choix du poste
    ├── home/       tableau de bord adaptatif par poste
    ├── controleur/ scan plein écran, saisie manuelle, historique, contrôle bagages
    ├── convoyeur/  manifeste, fiche passager, prochain arrêt, bagages, colis
    ├── chauffeur/  conduite (carte), itinéraire & GPS, clôture
    ├── business/   missions, remise / restitution guidées, signature
    └── common/     voyage, incidents, alertes, profil, synchronisation, aide
```

Stack : Flutter 3.44 · Riverpod 3 · go_router 18 · shared_preferences ·
connectivity_plus · mobile_scanner · flutter_map + OSM · geolocator ·
flutter_tts · image_picker. Design system partagé `core_ui`
(navy #002060 + orange #FF6600) avec une couleur métier par poste.

---

## 3. Connexion et inscription (inspirées de l'app client)

Parcours identique à `apps/client`, avec le **choix du poste pendant
l'inscription** :

```
Onboarding (1er lancement)
   └── Connexion ─────────────┬── Mot de passe oublié → Code SMS → Nouveau mot de passe → Connexion
       (+225 + mot de passe)   └── Créer mon compte agent
                                    1. Poste  2. Identité  3. Rattachement  4. Sécurité  5. Confirmation
                                    → Code SMS → Accueil du poste choisi
```

- **Connexion** : numéro +225 et mot de passe. Le poste appliqué est celui
  du compte ; un compte à plusieurs postes (ouvert par la compagnie) passe
  par l'écran « Quel est votre poste aujourd'hui ? ».
- **Inscription en 5 étapes** avec barre de progression :
  1. **Poste** : Contrôleur, Convoyeur, Chauffeur ou Agent BUSINESS ;
  2. **Identité** : prénom, nom, matricule et e-mail facultatifs ;
  3. **Rattachement** : compagnie + gare (postes transport) ou agence de
     location + site (Agent BUSINESS) ;
  4. **Sécurité** : numéro +225, mot de passe + confirmation, règles
     cochées en direct (mêmes règles que l'app client) ;
  5. **Confirmation** : récapitulatif, acceptation des CGU, puis code SMS.
- **Code SMS** : 6 cases, remplissage automatique, renvoi après 45 s,
  secousse en cas d'erreur.
- **Mot de passe temporaire** (compte créé par la compagnie) : changement
  obligatoire à la 1re connexion — exigence du CDC conservée.
- **Sécurité** : le mot de passe ne passe jamais par l'URL ; l'écran de
  code SMS et celui du nouveau mot de passe ne s'ouvrent que si une
  vérification est en cours.

**Comptes de démonstration** (mot de passe `Moncar2026`, code SMS `123456`) :

| Numéro | Poste |
|---|---|
| 07 00 00 00 01 | Contrôleur |
| 07 00 00 00 02 | Convoyeur |
| 07 00 00 00 03 | Chauffeur |
| 07 00 00 00 04 | Agent BUSINESS |
| 07 00 00 00 05 | Multi-postes (choix du poste à la connexion) |

Avec le mot de passe `Temp1234`, ces comptes simulent un mot de passe
temporaire. Les comptes créés par inscription restent sur le téléphone.

> ⚠️ **À arbitrer par la direction** : le CDC prévoit des comptes PRO
> **créés par la compagnie** (mot de passe temporaire). L'inscription
> demandée ici est donc traitée comme une **demande de compte rattachée à
> une compagnie / agence**, validée côté serveur. En démonstration la
> validation est immédiate. À confirmer avec le point A-1 de la roadmap.

---

## 4. Fonctionnalités par poste

**Contrôleur** — scan QR plein écran (caméra, lampe, anti-rebond), les
6 résultats du CDC (valide, déjà contrôlé, annulé, mauvais voyage, mauvaise
gare, invalide) en plein écran coloré avec vibration, « Confirmer
l'embarquement », saisie manuelle tracée, historique filtrable, contrôle
des bagages. Vérification locale sur le manifeste téléchargé : fonctionne
sans réseau.

**Convoyeur** — manifeste par segment (recalculé, jamais ajusté à la main)
avec bouton « Présent » par passager, fiche passager (présence,
débarquement qui libère le siège), prochain arrêt (descentes, montées,
sièges libérés, bagages, colis), suivi des bagages et des colis.

**Chauffeur** — écran de conduite centré sur la carte, une seule grande
action selon l'étape ; démarrer et clôturer se font en **glissant** le
bouton (anti-appui accidentel) ; alertes vocales « Arrêt à 1 km » /
arrivée ; itinéraire, GPS (simulation ou GPS du téléphone), envoi des
positions par lots de 10 ; clôture avec kilométrage et incident éventuel.

**Agent BUSINESS** — missions du jour ; remise et restitution guidées en
8 étapes : identité du client, véhicule et documents, 6 vraies photos,
kilométrage et carburant, checklist (comparée avant/après à la
restitution), anomalies et frais indicatifs, signature du client, preuve
renvoyée par le serveur.

**Commun** — tableau de bord adapté au poste, incidents (catégories selon
le poste, gravité, photo, position), alertes lues/non lues, profil
(thème clair/sombre/système, mode hors ligne d'essai, alertes vocales),
écran de synchronisation, aide par poste.

**Hors ligne** (principe n°6 de la roadmap) — chaque action est enregistrée
sur le téléphone avec son heure terrain et une clé d'idempotence, puis
renvoyée au retour du réseau, sans doublon ; bandeau « Mode hors ligne »
permanent.

---

## 5. Ajustements par rapport au prototype Next.js

| Sujet | Prototype | App Flutter | Raison |
|---|---|---|---|
| Couleurs | Bleu #14467D + or | Navy #002060 + orange #FF6600 (`core_ui`) + couleur par poste | Cohérence avec l'app client |
| Choix du poste | Avant la connexion | À l'inscription ; à la connexion seulement pour les comptes multi-postes | Demande de l'utilisateur + roadmap AUTH-002 |
| Postes | 3 | 4 (ajout Agent BUSINESS) | Roadmap §10.2 |
| Arrêts de démo | Bingerville, N'Zuessy | Abobo, Anyama, N'Douci, Toumodi, Yamoussoukro (coordonnées réelles) | Bingerville n'est pas sur l'axe |
| Compagnie de démo | UTB (réelle) | « Lagune Express (démo) » (fictive) | Éviter d'utiliser une vraie marque |
| Carte | SVG dessiné | flutter_map + OpenStreetMap | Carte réelle |

---

## 6. Limites connues / reste à faire

- Toutes les données sont simulées (`lib/core/data/pro_api.dart`) ; les
  chemins d'API visés y sont notés (roadmap §9).
- Vérification de la **signature des billets** hors ligne non faite :
  algorithme non tranché (**T-4**).
- **GPS en arrière-plan** non fait ; fréquence à fixer (**T-5**).
- File d'actions stockée dans les préférences du téléphone, en attendant le
  schéma **Drift** de `core_data`.
- Notifications push (FCM) non branchées (NOT-001).
- Textes CGU / confidentialité à fournir (**A-13**).
- Politique de mot de passe et durée du code SMS à confirmer (**T-8**).
- Icônes de l'app (Android, iOS, web) encore celles de Flutter par défaut.
- Aucun essai sur téléphone réel.

---

## 7. Lancer et tester

```bash
cd apps/pro
flutter run            # téléphone / émulateur
flutter run -d chrome  # démo navigateur (dossier web/)
flutter analyze
flutter test
```

---

## 8. Journal

### 25/09/2026 — Refonte connexion / inscription
- Connexion reprise de l'app client : numéro +225 + mot de passe,
  « Mot de passe oublié ? », bouton « Créer mon compte agent ».
- Nouvelle **inscription en 5 étapes** avec **choix du poste** en
  1re étape, rattachement compagnie/gare ou agence, code SMS.
- Nouveaux écrans : code SMS (6 cases), mot de passe oublié, nouveau mot
  de passe. Écran « mot de passe temporaire » aligné sur les mêmes règles.
- Suppression de la connexion par code SMS seul (l'app client ne l'a pas).
- Comptes de démo par poste ; comptes créés conservés sur le téléphone.
- Composants partagés : `features/auth/widgets/auth_widgets.dart`,
  `role_card.dart`.
- Corrections : bouton « Glisser pour confirmer » (erreur au démontage en
  mode debug) ; interrupteurs et cases à cocher dans les cartes (effet
  d'appui invisible, alerte Flutter en debug) sur 7 écrans.
- Tests : connexion avec compte de démo, mauvais mot de passe, parcours
  d'inscription complet, règles des comptes → **12 tests verts**.

### 25/09/2026 — Ajout de la cible web
- Dossier `web/` (page HTML + manifeste « MON CAR PRO ») pour compiler et
  faire des démos dans le navigateur. Non utilisé par Android / iOS ;
  peut être supprimé.

### 25/09/2026 — Portage du prototype Next.js vers Flutter
- Lecture des deux documents de référence, puis portage des écrans du
  prototype dans `apps/pro` avec l'architecture ci-dessus.
- Ajout du poste Agent BUSINESS, de la file hors ligne, de la carte réelle,
  des alertes vocales et des vraies photos.
- Permissions Android (caméra, localisation, internet) et textes
  d'autorisation iOS ; nom de l'app « MON CAR PRO ».
- `flutter analyze` sans problème ; 7 tests verts à cette date.
