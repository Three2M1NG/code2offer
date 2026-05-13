import 'dart:io' show Platform;

class AppConfig {
  static const String _compileTimeUrl = String.fromEnvironment('API_BASE_URL');
  static const String _androidDefault = 'http://10.0.2.2:8000';
  static const String _fallbackDefault = 'http://localhost:8000';

  static String get apiBaseUrl {
    if (_compileTimeUrl.isNotEmpty) return _compileTimeUrl;
    try {
      if (Platform.isAndroid) return _androidDefault;
    } catch (_) {}
    return _fallbackDefault;
  }
}
