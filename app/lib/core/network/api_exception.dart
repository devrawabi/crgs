import 'package:dio/dio.dart';

class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.originalError,
  });

  final String message;
  final int? statusCode;
  final dynamic originalError;

  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    final data = response?.data;
    String message = 'An unexpected error occurred';

    if (data is Map && data['error'] != null) {
      message = data['error'].toString();
    } else if (data is Map && data['message'] != null) {
      message = data['message'].toString();
    } else if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      message =
          'Connection timed out. Is the CRGS API running on this PC '
          '(port 5318)? If using the public URL, start the Cloudflare tunnel.';
    } else if (error.type == DioExceptionType.connectionError) {
      message =
          'Cannot reach the server. Start the backend (port 5318) '
          'or check Wi‑Fi / Cloudflare tunnel.';
    } else if (response?.statusCode == 401) {
      message = 'Session expired. Please login again.';
    } else if (response?.statusCode == 403) {
      message = 'You do not have permission for this action.';
    } else if (response?.statusCode == 404) {
      message = 'Resource not found.';
    }

    return ApiException(
      message: message,
      statusCode: response?.statusCode,
      originalError: error,
    );
  }

  @override
  String toString() => message;
}
