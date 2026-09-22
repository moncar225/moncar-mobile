/// MON CAR — couche de données locale (Drift) pour les apps client et pro.
///
/// Rôle prévu : cache hors-ligne et files d'attente locaux (billets hors ligne,
/// brouillons de réservation/colis, géolocalisation récente…).
///
/// ⚠️ Squelette volontairement vide de schéma : les tables seront définies à
/// partir du contrat OpenAPI du backend (source de vérité), pas inventées.
/// La génération de code se fera via `dart run build_runner build`
/// (dépendances build_runner/drift_dev déjà présentes).
library;
