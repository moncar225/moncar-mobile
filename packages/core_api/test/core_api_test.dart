import 'package:flutter_test/flutter_test.dart';

import 'package:core_api/core_api.dart';

void main() {
  group('messageForStatusCode', () {
    test('retourne le message français standard pour chaque code géré', () {
      for (final code in [400, 401, 403, 404, 409, 422, 429, 500]) {
        final message = messageForStatusCode(code);
        expect(message, isNotEmpty, reason: 'code $code');
        expect(message, isNot(contains('Error')), reason: 'code $code');
      }
    });

    test('401 parle de session expirée, 429 de trop de requêtes', () {
      expect(messageForStatusCode(401), contains('session'));
      expect(messageForStatusCode(429), contains('Trop de requêtes'));
    });

    test('code inconnu → message générique', () {
      expect(
        messageForStatusCode(599),
        contains('erreur inattendue'),
      );
    });

    test('le message serveur (fallback) prime pour les codes non standards', () {
      expect(
        messageForStatusCode(507, fallback: 'Stockage insuffisant.'),
        'Stockage insuffisant.',
      );
    });
  });

  group('ApiException', () {
    test('isNetworkError uniquement pour statusCode -1', () {
      const network = ApiException(statusCode: -1, message: 'Connexion impossible.');
      const http = ApiException(statusCode: 404, message: 'Ressource introuvable.');

      expect(network.isNetworkError, isTrue);
      expect(http.isNetworkError, isFalse);
    });
  });

  group('ApiClient (sans réseau)', () {
    test('setAuthorization/clearAuthorization gèrent le header de session', () {
      final client = ApiClient(baseUrl: 'https://api.example.test');

      client.setAuthorization('token-test');
      client.clearAuthorization();
      // Aucune exception : la gestion du header ne doit jamais échouer.
    });
  });
}
