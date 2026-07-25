import 'package:flutter/foundation.dart';

/// Backend API base URL — same Flask service as CRGS-Admin web portal.
///
/// Override at build/run time:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.61.41:5000/api`
abstract final class ApiConfig {
  static const String _host = '192.168.61.41';
  static const String _apiBase = 'http://$_host:5000/api';

  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    if (kIsWeb) {
      return _apiBase;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _apiBase;
      default:
        return _apiBase;
    }
  }
}
