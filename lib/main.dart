import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'core/services/auth_service.dart';
import 'core/session/sesion_expirada.dart';
import 'core/ui/tema.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'features/home/home_screen.dart';

/// Clave global del ScaffoldMessenger: permite mostrar el aviso de sesión
/// vencida sin depender de un BuildContext que pueda estar desmontado.
final GlobalKey<ScaffoldMessengerState> fsScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() {
  runApp(const FashionStoreApp());
}

class FashionStoreApp extends StatefulWidget {
  const FashionStoreApp({super.key});

  @override
  State<FashionStoreApp> createState() => _FashionStoreAppState();
}

class _FashionStoreAppState extends State<FashionStoreApp> {
  bool? _tieneSesion;
  int _generacion = 0;
  final ManejadorSesionExpirada _manejador401 = ManejadorSesionExpirada();

  @override
  void initState() {
    super.initState();
    // Cierre de sesión controlado ante 401 del servidor.
    ApiClient.onNoAutorizadoGlobal = _alRecibir401Global;
  }

  @override
  void dispose() {
    if (identical(ApiClient.onNoAutorizadoGlobal, _alRecibir401Global)) {
      ApiClient.onNoAutorizadoGlobal = null;
    }
    super.dispose();
  }

  /// Gancho síncrono del ApiClient: delega al manejador con protección
  /// contra ráfagas (un aviso, una limpieza, navegación segura).
  void _alRecibir401Global() {
    _manejador401.manejar(
      limpiarSesion: AuthService().cerrarSesion,
      mostrarAviso: () {
        fsScaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Tu sesión venció. Vuelve a iniciar sesión.'),
          ),
        );
      },
      irALogin: () {
        if (!mounted) return;
        setState(() {
          _tieneSesion = false;
          _generacion++;
        });
      },
    );
  }

  void _irA(bool ok) => setState(() {
        _tieneSesion = ok;
        _generacion++;
      });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FashionStore',
      debugShowCheckedModeBanner: false,
      theme: temaFashionStore(),
      scaffoldMessengerKey: fsScaffoldMessengerKey,
      home: _tieneSesion == null
          ? SplashScreen(onDecidido: _irA)
          : _tieneSesion == true
              ? HomeScreen(
                  key: ValueKey('home-$_generacion'),
                  onSesionCerrada: () => _irA(false),
                )
              : LoginScreen(
                  key: ValueKey('login-$_generacion'),
                  onLoginOk: () => _irA(true),
                ),
    );
  }
}
