/// Stockage sécurisé de la session MON CAR (mobile client & pro).
///
/// Infrastructure : ce fichier déclare le SEAM d'accès au keystore/keychain.
/// AUCUN secret n'est stocké en dur. L'implémentation réelle est fournie par
/// les apps (via `flutter_secure_storage`) ou par un double in-memory en test.
library;

/// Jeton + expiration stockés de façon sécurisée (Keychain iOS / Keystore Android).
class SecureSession {
  const SecureSession({
    required this.token,
    required this.expiresAt,
    this.refreshToken,
    required this.userId,
  });

  final String token;
  final DateTime expiresAt;
  final String? refreshToken;
  final String userId;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);
}

/// Contrat de stockage session — implémenté dans les apps ou en memory pour
/// les tests. Ne déclare AUCUN endpoint ; on ne sait pas encore quel
/// endpoint /refresh le contrat OpenAPI exposera.
abstract class SecureSessionStore {
  Future<SecureSession?> load();
  Future<void> save(SecureSession session);
  Future<void> clear();
}

/// Implémentation par défaut : stockage pur in-memory.
///
/// ⚠️ Les apps client/pro DOIVENT surcharger `sessionStore` par un
/// `flutter_secure_storage` avant le premier appel réseau.
class InMemorySecureSessionStore implements SecureSessionStore {
  SecureSession? _session;

  @override
  Future<SecureSession?> load() async => _session;

  @override
  Future<void> save(SecureSession session) async {
    _session = session;
  }

  @override
  Future<void> clear() async {
    _session = null;
  }
}
