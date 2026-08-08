import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import 'api_exception.dart';

/// Central HTTP client for API integration.
/// Wire interceptors for auth tokens, logging, and offline queue.
class ApiClient {
  ApiClient({Dio? dio}) : _dio = dio ?? _createDio() {
    _dio.interceptors.add(_AuthInterceptor(this));
  }

  final Dio _dio;
  String? _authToken;
  String? get authToken => _authToken;

  FutureOr<void> Function()? _onUnauthorized;
  bool _handlingUnauthorized = false;

  /// Called once when a protected request returns 401.
  void setUnauthorizedHandler(FutureOr<void> Function()? handler) {
    _onUnauthorized = handler;
  }

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        // Tunnel + Oracle can be slow; keep connect/receive generous.
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 45),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    dio.interceptors.add(
      _RetryInterceptor(
        dio: dio,
        maxRetries: 3,
        baseDelay: const Duration(milliseconds: 400),
      ),
    );
    return dio;
  }

  void setAuthToken(String? token) {
    _authToken = token;
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  Future<void> _notifyUnauthorized() async {
    if (_handlingUnauthorized) return;
    final handler = _onUnauthorized;
    if (handler == null) return;
    _handlingUnauthorized = true;
    try {
      await handler();
    } finally {
      _handlingUnauthorized = false;
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get<T>(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Multipart POST (e.g. product review with optional image).
  Future<Response<T>> postMultipart<T>(
    String path, {
    required FormData data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          contentType: 'multipart/form-data',
          headers: {'Accept': 'application/json'},
        ),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
  }) async {
    try {
      return await _dio.put<T>(path, data: data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
  }) async {
    try {
      return await _dio.patch<T>(path, data: data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

/// Forces session teardown on 401 from protected endpoints.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this.client);

  final ApiClient client;

  bool _isPublicAuthPath(RequestOptions options) {
    final path = options.path;
    return path == ApiEndpoints.login ||
        path.endsWith(ApiEndpoints.login) ||
        path.contains('${ApiEndpoints.login}?');
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;
    if (status == 401 && !_isPublicAuthPath(err.requestOptions)) {
      // Clear token immediately so follow-up calls don't keep using it.
      client.setAuthToken(null);
      unawaited(client._notifyUnauthorized());
    }
    handler.next(err);
  }
}

/// Retries transient network / 5xx failures with exponential backoff.
/// Safe POSTs (visit start/end) are retried — backend start is idempotent.
class _RetryInterceptor extends Interceptor {
  _RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.baseDelay = const Duration(milliseconds: 400),
  });

  final Dio dio;
  final int maxRetries;
  final Duration baseDelay;

  static const _retryableMethods = {'GET', 'HEAD', 'OPTIONS'};

  /// Visit start/end tolerate retries (start reuses an open visit row).
  static bool _isRetryablePost(RequestOptions request) {
    if (request.method.toUpperCase() != 'POST') return false;
    final path = request.path;
    return path == ApiEndpoints.visitsStart ||
        path.endsWith(ApiEndpoints.visitsStart) ||
        path == ApiEndpoints.visitsEnd ||
        path.endsWith(ApiEndpoints.visitsEnd);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final attempt = (request.extra['retry_attempt'] as int?) ?? 0;
    final method = request.method.toUpperCase();
    final canRetryMethod =
        _retryableMethods.contains(method) || _isRetryablePost(request);

    if (attempt >= maxRetries || !canRetryMethod) {
      return handler.next(err);
    }
    if (!_shouldRetry(err)) {
      return handler.next(err);
    }

    final delay = baseDelay * math.pow(2, attempt).toInt();
    await Future<void>.delayed(delay);

    final options = request.copyWith(
      extra: {
        ...request.extra,
        'retry_attempt': attempt + 1,
      },
    );

    try {
      final response = await dio.fetch(options);
      return handler.resolve(response);
    } on DioException catch (retryError) {
      return handler.next(retryError);
    }
  }

  bool _shouldRetry(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final code = err.response?.statusCode ?? 0;
        return code == 408 || code == 429 || code >= 500;
      default:
        return false;
    }
  }
}
