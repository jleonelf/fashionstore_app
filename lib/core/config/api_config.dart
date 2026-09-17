import 'package:flutter/foundation.dart';

/// Resolución de la URL base del backend.
///
/// Uso:
/// ```
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
/// ```
/// Valores locales sugeridos:
/// - Emulador Android: http://10.0.2.2:8000/api/v1
/// - Chrome / escritorio: http://127.0.0.1:8000/api/v1
/// - Teléfono físico: http://IP_DEL_EQUIPO:8000/api/v1
class ApiConfig {
  static const String _envKey = 'API_BASE_URL';

  /// URL definida por --dart-define, vacía si no se pasó.
  static const String _envUrl = String.fromEnvironment(_envKey);

  /// Base por defecto según plataforma cuando no hay dart-define.
  static String get _defaultForPlatform {
    if (kIsWeb) return 'http://127.0.0.1:8000/api/v1';
    // Android emulador usa 10.0.2.2; iOS simulator y escritorio usan localhost.
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000/api/v1';
      default:
        return 'http://127.0.0.1:8000/api/v1';
    }
  }

  static String get baseUrl {
    final v = _envUrl.trim();
    if (v.isNotEmpty) return v.replaceAll(RegExp(r'/+$'), '');
    return _defaultForPlatform;
  }

  /// Mensaje corto para pantallas de ayuda / diagnóstico.
  static String get origenDescripcion {
    if (_envUrl.trim().isNotEmpty) return 'configurada por la app ($_envKey)';
    if (kIsWeb) return 'automática para navegador';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'automática para emulador Android';
    }
    return 'automática local';
  }
}
