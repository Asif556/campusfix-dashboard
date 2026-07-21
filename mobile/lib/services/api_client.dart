import 'package:dio/dio.dart';

import 'session_store.dart';

/// A friendly, already-humanized API error. Services throw this so the UI can
/// surface `e.message` directly (matching the backend's `{ "error": "..." }`).
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final int? retryAfter; // seconds, present on OTP rate-limit (429) responses

  ApiException(this.message, {this.statusCode, this.retryAfter});

  @override
  String toString() => message;
}

/// Thin singleton wrapper around Dio. The base URL is resolved from
/// [SessionStore] on every request, so changing the server in Settings takes
/// effect immediately without rebuilding the client.
class ApiClient {
  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        // Treat non-2xx as errors we translate; we read the body ourselves.
        validateStatus: (code) => code != null && code < 400,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.baseUrl = SessionStore.instance.baseUrl;
          final token = SessionStore.instance.token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (err, handler) {
          final path = err.requestOptions.path;
          final status = err.response?.statusCode;
          // Expired/invalid session on a non-auth route → sign the user out.
          if (status == 401 && !path.contains('/auth/')) {
            onUnauthorized?.call();
          }
          handler.next(err);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._();

  late final Dio _dio;

  /// Invoked when a protected call returns 401 (session expired). Wired by the
  /// auth layer to force a logout + redirect.
  void Function()? onUnauthorized;

  Dio get dio => _dio;

  /// Convert any thrown error into a user-facing [ApiException].
  static ApiException toApiException(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      final data = error.response?.data;
      String? message;
      int? retryAfter;
      if (data is Map) {
        final err = data['error'] ?? data['message'];
        if (err != null) message = err.toString();
        final ra = data['retry_after'];
        if (ra is num) retryAfter = ra.toInt();
      }
      message ??= switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout =>
          'The server took too long to respond. Check your connection and the '
              'server address in Settings.',
        DioExceptionType.connectionError =>
          'Could not reach the server. Make sure the backend is running and the '
              'server address in Settings is correct.',
        _ => 'Something went wrong. Please try again.',
      };
      return ApiException(
        message,
        statusCode: error.response?.statusCode,
        retryAfter: retryAfter,
      );
    }
    return ApiException(error.toString());
  }
}
