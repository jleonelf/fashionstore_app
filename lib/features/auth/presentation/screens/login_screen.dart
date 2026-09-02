import 'package:flutter/material.dart';
import '../../../../core/services/auth_service.dart';
import 'registro_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  final _correoController = TextEditingController();
  final _contraseniaController = TextEditingController();

  bool _cargando = false;
  String? _mensajeError;

  @override
  void dispose() {
    _correoController.dispose();
    _contraseniaController.dispose();
    super.dispose();
  }

  void _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _mensajeError = null;
    });

    try {
      final respuesta = await _authService.iniciarSesion(
        correoElectronico: _correoController.text.trim(),
        contrasenia: _contraseniaController.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Hola de nuevo, ${respuesta.usuario.nombreCompleto}!'),
          backgroundColor: Colors.blueAccent,
        ),
      );
      // Aquí se navegaría a la pantalla principal del catálogo
    } catch (e) {
      setState(() {
        _mensajeError = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.shopping_bag_outlined, size: 72, color: Colors.blueAccent),
                  const SizedBox(height: 16),
                  const Text(
                    'FashionStore',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Inicia sesión para continuar',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  if (_mensajeError != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(_mensajeError!, style: TextStyle(color: Colors.red.shade800)),
                    ),
                  TextFormField(
                    controller: _correoController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Correo Electrónico', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty ? 'Ingrese su correo' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contraseniaController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty ? 'Ingrese su contraseña' : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _cargando ? null : _iniciarSesion,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _cargando
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Iniciar Sesión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('¿No tienes cuenta? '),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RegistroScreen()),
                          );
                        },
                        child: const Text('Regístrate aquí', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
