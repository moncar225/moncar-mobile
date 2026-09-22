/// Erreur normalisée levée pour toute réponse HTTP non réussie (>= 400) ou
/// échec réseau. Les apps ne manipulent que cette exception, jamais les
/// exceptions brutes de dio.
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.message,
    this.incidentId,
    this.origin,
  });

  /// Code HTTP de la réponse, ou `-1` pour un échec réseau (connexion
  /// impossible, timeout, etc.).
  final int statusCode;

  /// Message compréhensible en français, prêt à afficher à l'utilisateur.
  final String message;

  /// Référence d'incident fournie par le serveur si disponible (ex. header
  /// `X-Request-Id` ou champ `incidentId` du corps d'erreur 500).
  final String? incidentId;

  /// Erreur d'origine (dio, socket…) pour le diagnostic, jamais affichée.
  final Object? origin;

  bool get isNetworkError => statusCode == -1;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
