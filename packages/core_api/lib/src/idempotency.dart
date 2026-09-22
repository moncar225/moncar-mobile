/// Idempotency-Key + horodatage (infrastructure, sans logique métier).
///
/// Règles appliquées :
/// - Idempotency-Key ajoutée automatiquement sur POST/PUT/PATCH/DELETE
///   lorsque le header n'est pas déjà positionné ;
/// - X-Request-Timestamp ajouté lorsque `timestampEnabled` est vrai
///   (drapeau à basculer lorsque le contrat OpenAPI officiel l'exigera).
///
/// Aucune logique métier : ce module ne sait pas quelles routes sont
/// "sensibles". Le client généré OpenAPI positionnera lui-même
/// `skipIdempotency` ou pré-remplira les headers pour les exceptions.
library;

import 'dart:math';

const _defaultIdempotentMethods = {'POST', 'PUT', 'PATCH', 'DELETE'};

class IdempotencyTimestampManager {
  IdempotencyTimestampManager({
    Set<String>? methods,
    this.headerName = 'Idempotency-Key',
    this.timestampHeaderName = 'X-Request-Timestamp',
    this.timestampEnabled = false,
    String Function()? keyGenerator,
  })  : methods = methods ?? _defaultIdempotentMethods,
        _keyGenerator = keyGenerator ?? _defaultGenerateKey;

  final Set<String> methods;
  final String headerName;
  final String timestampHeaderName;
  final bool timestampEnabled;
  final String Function() _keyGenerator;

  static final Random _random = Random.secure();

  static String _defaultGenerateKey() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  void enrichHeaders(String method, Map<String, dynamic> headers) {
    final upper = method.toUpperCase();
    if (!headers.containsKey(headerName) && methods.contains(upper)) {
      headers[headerName] = _keyGenerator();
    }
    if (timestampEnabled && !headers.containsKey(timestampHeaderName)) {
      headers[timestampHeaderName] =
          DateTime.now().toUtc().millisecondsSinceEpoch.toString();
    }
  }
}
