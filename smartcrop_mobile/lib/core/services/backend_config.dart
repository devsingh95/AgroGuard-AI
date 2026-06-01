import 'package:flutter/foundation.dart';

class BackendConfig {
  static const String _configuredOrigin =
      String.fromEnvironment('AGROGUARD_BACKEND_ORIGIN');

  static String get origin {
    final configured = _configuredOrigin.trim();
    if (configured.isNotEmpty) {
      return _normalize(configured);
    }

    if (kIsWeb) {
      final webOrigin = Uri.base.origin;
      if (webOrigin.isNotEmpty && webOrigin != 'null') {
        return _normalize(webOrigin);
      }
    }

    return 'http://localhost:5000';
  }

  static Uri apiUri(String path, {Map<String, String>? queryParameters}) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$origin$normalizedPath').replace(
      queryParameters: queryParameters,
    );
  }

  static String _normalize(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}