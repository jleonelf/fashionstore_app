import 'package:flutter/material.dart';

import '../../../core/config/api_config.dart';
import '../models/usuario_model.dart';
import '../services/auth_service.dart';
import '../auth/presentation/screens/login_screen.dart';

/// Perfil + ayuda de conexión + cierre de sesión.
/// En modo invitado muestra acceso a login/registro sin bloquear el catálogo.
class CuentaScreen extends StatefulWidget {
  final VoidCallback onSesionCerrada;
  final VoidCallback? onSesionIniciada;
  const CuentaScreen(
      {super.key, required this.onSesionCerrada, this.onSesionIniciada});

  @override
  State<CuentaScreen> createState() => _CuentaScreenState();
}

class _CuentaScreenState extends State<CuentaScreen> {
  final _auth = AuthService();
  ClientePerfilModel? _usuario;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final s = await _auth.sesionActual();
    if (mounted) {
      setState(() {
        _usuario = s?.usuario;
        _cargando = false;
      });
    }
  }

  Future<void> _salir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Deseas salir de tu cuenta en este equipo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _auth.cerrarSesion();
    widget.onSesionCerrada();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_usuario == null) {
      // Modo invitado: catálogo público + puerta de login solo aquí.
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Explora sin cuenta',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    SizedBox(height: 6),
                    Text(
                      'El catálogo es público. Inicia sesión solo cuando quieras comprar, reservar o probar prendas.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () async {
                final ok = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Inicia sesión')),
                      body: LoginScreen(onLoginOk: () {}),
                    ),
                  ),
                );
                // LoginScreen dentro de Home ya gestiona el retorno; aquí
                // solo refrescamos por si el flujo devolvió directo.
                if (ok == true && context.mounted) {
                  await _cargar();
                  widget.onSesionIniciada?.call();
                } else {
                  await _cargar();
                }
              },
              icon: const Icon(Icons.login_outlined),
              label: const Text('Iniciar sesión'),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Conexión',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    SelectableText(
                      ApiConfig.baseUrl,
                      style: TextStyle(color: Colors.grey.shade800),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    child: Text(
                      (_usuario?.nombreCompleto.isNotEmpty ?? false)
                          ? _usuario!.nombreCompleto[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _usuario?.nombreCompleto ?? 'Cliente',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 17),
                        ),
                        Text(
                          _usuario?.correoElectronico ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Conexión',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  SelectableText(
                    ApiConfig.baseUrl,
                    style: TextStyle(color: Colors.grey.shade800),
                  ),
                  Text(
                    'Dirección ${ApiConfig.origenDescripcion}. Si cambias de red (emulador, navegador o teléfono), abre la app con su dirección correspondiente.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _salir,
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
            ),
          ),
        ],
      ),
    );
  }
}
