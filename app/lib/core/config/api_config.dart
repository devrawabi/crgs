import 'package:flutter/foundation.dart';

/// Backend API base URL — CRGS Cloudflare Tunnel API.
///
/// Production default:
///   https://crgs-api.rfoodinternational.com/api
///
/// Local override example:
///   flutter run --dart-define=API_BASE_URL=http://192.168.61.41:5318/api
///   flutter build apk --dart-define=API_BASE_URL=https://crgs-api.rfoodinternational.com/api
abstract final class ApiConfig {
  static const String productionApi =
      'https://crgs-api.rfoodinternational.com/api';

  /// Local API used by Flutter web debug (Chrome/Edge).
  static const String localApi = 'http://127.0.0.1:5318/api';

  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    // Flutter web on localhost is blocked by production CORS; use local API in debug.
    if (kDebugMode && kIsWeb) return localApi;
    return productionApi;
  }
}
