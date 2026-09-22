/// Messages d'erreur API compréhensibles en français, partagés par les apps
/// MON CAR (client et pro). La logique de mapping est identique côté web.
const Map<int, String> apiErrorMessages = {
  400: 'Requête invalide. Vérifiez les informations saisies.',
  401: 'Votre session a expiré. Veuillez vous reconnecter.',
  403: 'Accès interdit. Vous ne pouvez pas effectuer cette action.',
  404: 'Ressource introuvable.',
  409: 'Conflit : les données ont changé entre-temps. Rechargez les données puis réessayez.',
  422: 'Les données envoyées sont invalides. Vérifiez les champs signalés.',
  429: 'Trop de requêtes. Veuillez patienter un instant avant de réessayer.',
  500: 'Une erreur est survenue côté serveur. Veuillez réessayer plus tard.',
};

/// Retourne le message français correspondant à un code HTTP.
///
/// Si le serveur fournit un message métier dans le corps de la réponse,
/// celui-ci est prioritaire (voir [ApiException.message]).
String messageForStatusCode(int statusCode, {String? fallback}) {
  return apiErrorMessages[statusCode] ??
      fallback ??
      'Une erreur inattendue est survenue. Veuillez réessayer.';
}
