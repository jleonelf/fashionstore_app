class ApiConstants {
  // Para emulador Android usar 10.0.2.2, para dispositivo físico o web usar IP de red local
  static const String baseUrl = 'http://10.0.2.2:8000/api/v1';

  static const String endpointClientes = '$baseUrl/clientes';
  static const String endpointSesion = '$baseUrl/sesion';
}
