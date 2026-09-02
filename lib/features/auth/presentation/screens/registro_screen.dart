import 'package:flutter/material.dart';
import '../../../../core/services/auth_service.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _correoController = TextEditingController();
  final _contraseniaController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();

  bool _cargando = false;
  String? _mensajeError;

  @override
  void dispose() {
    _nombresController.dispose();
    _apellidosController.dispose();
    _correoController.dispose();
    _contraseniaController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  void _registrarCliente() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _mensajeError = null;
    });

    try {
      final cliente = await _authService.registrarCliente(
        nombres: _nombresController.text.trim(),
        apellidos: _apellidosController.text.trim(),
        correoElectronico: _correoController.text.trim(),
        contrasenia: _contraseniaController.text,
        telefono: _telefonoController.text.trim(),
        direccionReferencia: _direccionController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Bienvenido ${cliente.nombreCompleto}! Cuenta creada exitosamente.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
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
      appBar: AppBar(
        title: const Text('Crear Cuenta'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Únete a FashionStore',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Regístrate para probar prendas en vestidor virtual y reservar en tienda.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
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
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nombresController,
                        decoration: const InputDecoration(labelText: 'Nombres *', border: OutlineInputBorder()),
                        validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _apellidosController,
                        decoration: const InputDecoration(labelText: 'Apellidos *', border: OutlineInputBorder()),
                        validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _correoController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo Electrónico *', border: OutlineInputBorder()),
                  validator: (v) => v == null || !v.contains('@') ? 'Correo no válido' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contraseniaController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña * (mínimo 6 caracteres)', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _telefonoController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Teléfono / Celular', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _direccionController,
                  decoration: const InputDecoration(labelText: 'Dirección de Referencia', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _cargando ? null : _registrarCliente,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _cargando
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Registrarse', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
