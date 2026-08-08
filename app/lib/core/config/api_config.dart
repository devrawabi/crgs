import 'package:flutter/foundation.dart';

/// Backend API base URL — CRGS Cloudflare Tunnel API.
///
/// Production default:
///   https://crgs-api.rfoodinternational.com/api
///
/// Local override examples:
///   flutter run --dart-define=API_BASE_URL=http://192.168.61.41:5318/api
///   flutter run --dart-define=LOCAL_API_HOST=192.168.61.41
///   flutter build apk --dart-define=API_BASE_URL=https://crgs-api.rfoodinternational.com/api
abstract final class ApiConfig {
  static const String productionApi =
      'https://crgs-api.rfoodinternational.com/api';

  /// Local API used by Flutter web debug (Chrome/Edge).
  static const String localApi = 'http://127.0.0.1:5318/api';

  /// LAN host for physical Android devices / emulators during debug.
  /// Override with `--dart-define=LOCAL_API_HOST=x.x.x.x`.
  static const String defaultLanHost = '192.168.61.41';

  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    // Debug builds must not depend on the Cloudflare tunnel — it is often
    // down when the origin PC sleeps or cloudflared isn't running.
    if (kDebugMode) {
      if (kIsWeb) return localApi;

      const lanHost = String.fromEnvironment('LOCAL_API_HOST');
      final host = lanHost.isNotEmpty ? lanHost : defaultLanHost;
      return 'http://$host:5318/api';
    }

    return productionApi;
  }
}
