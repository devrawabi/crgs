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

  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    return productionApi;
  }
}
