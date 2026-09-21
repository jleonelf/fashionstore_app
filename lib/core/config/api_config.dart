/// Resolución de la URL base del backend (única fuente de verdad).
///
/// La app generada apunta por defecto al backend FastAPI desplegado en Render.
/// Para desarrollo local se puede sobrescribir sin cambiar el código:
///   `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1`
/// Decart: la app nunca recibe ni guarda DECART_API_KEY; solo solicita al
/// backend `POST /api/v1/probador/autorizaciones` y usa el `client_token`
/// temporal en memoria con el modelo fijo `lucy-2.5`.
class ApiConfig {
  static const String _envKey = 'API_BASE_URL';
  static const String _renderUrl =
      'https://fashionstore-backend-natk.onrender.com/api/v1';

  /// URL definida por --dart-define, vacía si no se pasó.
  static const String _envUrl = String.fromEnvironment(_envKey);

  static String get baseUrl {
    final v = _envUrl.trim();
    if (v.isNotEmpty) return v.replaceAll(RegExp(r'/+$'), '');
    return _renderUrl;
  }

  /// Mensaje corto para pantallas de ayuda / diagnóstico.
  static String get origenDescripcion {
    if (_envUrl.trim().isNotEmpty) return 'configurada por la app ($_envKey)';
    return 'backend de producción en Render';
  }
}
