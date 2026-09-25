/// MON CAR — couche API mobile partagée (apps client et pro).
///
/// Infrastructure pure : client HTTP centralisé et gestion commune des erreurs.
/// Ce package ne connaît AUCUN endpoint métier : les chemins d'API proviennent
/// exclusivement du contrat OpenAPI du backend (source de vérité). Si un
/// endpoint n'est pas documenté, il ne doit pas exister dans ce package.
library;

export 'src/api_client.dart';
export 'src/app_environment.dart';
export 'src/api_error_messages.dart';
export 'src/api_exception.dart';
export 'src/idempotency.dart';
export 'src/secure_session_store.dart';
