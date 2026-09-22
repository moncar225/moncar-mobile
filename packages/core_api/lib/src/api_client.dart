/// Client HTTP centralisé de MON CAR (apps mobiles client et pro).
///
/// Infrastructure pure : ce client ne déclare aucun endpoint métier. Les
/// features appellent [get]/[post]/[put]/[patch]/[delete] avec les chemins
/// définis par le contrat OpenAPI du backend (source de vérité).
///
/// Toute erreur est normalisée en [ApiException] avec un message en français.
library;

import 'package:dio/dio.dart';

import 'api_error_messages.dart';
import 'api_exception.dart';

/// Extrait une référence d'incident d'une réponse d'erreur serveur.
typedef IncidentIdExtractor = String? Function(Response<dynamic>? response);

class ApiClient {
  ApiClient({
    required String baseUrl,
    Dio? dio,
    Map<String, String>? headers,
    IncidentIdExtractor? incidentIdExtractor,
  })  : _dio = dio ?? Dio(),
        _incidentIdExtractor = incidentIdExtractor ?? _defaultIncidentIdExtractor {
    if (dio == null) {
      _dio.options = BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: headers,
      );
    }
    _dio.interceptors.add(InterceptorsWrapper(onError: _mapError));
  }

  final Dio _dio;
  final IncidentIdExtractor _incidentIdExtractor;

  static String? _defaultIncidentIdExtractor(Response<dynamic>? response) {
    final header = response?.headers.value('x-request-id');
    if (header != null) return header;
    final body = response?.data;
    if (body is Map<String, dynamic>) {
      final id = body['incidentId'] ?? body['requestId'];
      if (id is String) return id;
    }
    return null;
  }

  /// Injecte le token de session (fourni par la couche auth des apps).
  /// Aucun secret n'est stocké en dur dans le code.
  void setAuthorization(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearAuthorization() {
    _dio.options.headers.remove('Authorization');
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) =>
      _send(() => _dio.get<dynamic>(
            path,
            queryParameters: query,
            options: Options(headers: headers),
          ));

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) =>
      _send(() => _dio.post<dynamic>(
            path,
            data: body,
            options: Options(headers: headers),
          ));

  Future<dynamic> put(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) =>
      _send(() => _dio.put<dynamic>(
            path,
            data: body,
            options: Options(headers: headers),
          ));

  Future<dynamic> patch(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) =>
      _send(() => _dio.patch<dynamic>(
            path,
            data: body,
            options: Options(headers: headers),
          ));

  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) =>
      _send(() => _dio.delete<dynamic>(
            path,
            data: body,
            options: Options(headers: headers),
          ));

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (e) {
      final error = e.error;
      if (error is ApiException) throw error;
      throw ApiException(
        statusCode: -1,
        message: messageForStatusCode(-1),
        origin: e,
      );
    }
  }

  void _mapError(DioException error, ErrorInterceptorHandler handler) {
    final response = error.response;

    if (response == null) {
      // Pas de réponse : réseau indisponible ou timeout.
      handler.reject(DioException(
        requestOptions: error.requestOptions,
        error: ApiException(
          statusCode: -1,
          message: 'Connexion impossible. Vérifiez votre connexion internet puis réessayez.',
          origin: error,
        ),
      ));
      return;
    }

    final serverMessage = _extractServerMessage(response.data);
    handler.reject(DioException(
      requestOptions: error.requestOptions,
      error: ApiException(
        statusCode: response.statusCode ?? -1,
        message: messageForStatusCode(response.statusCode ?? -1, fallback: serverMessage),
        incidentId: _incidentIdExtractor(response),
        origin: error,
      ),
    ));
  }

  /// Le message métier du serveur, s'il en fournit un, prime sur le message
  /// générique (sauf cas connus comme 401/403 où l'on garde un libellé clair).
  static String? _extractServerMessage(Object? body) {
    if (body is Map<String, dynamic>) {
      final message = body['message'] ?? body['detail'] ?? body['error'];
      if (message is String && message.isNotEmpty) return message;
    }
    return null;
  }
}
