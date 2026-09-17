import 'package:flutter/material.dart';

import '../../core/models/compra_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/historial_service.dart';
import '../../core/ui/async_view.dart';
import '../../core/ui/formato.dart';

/// Historial paginado de compras del cliente.
class HistorialScreen extends StatefulWidget {
  final HistorialService? servicioHistorial;
  final AuthService? servicioAuth;
  const HistorialScreen({super.key, this.servicioHistorial, this.servicioAuth});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  late final HistorialService _srv;
  late final AuthService _auth;
  List<Compra> _items = [];
  bool _cargando = true;
  String? _error;
  int _offset = 0;
  static const _limite = 20;
  bool _hayMas = true;

  @override
  void initState() {
    super.initState();
    _srv = widget.servicioHistorial ?? HistorialService();
    _auth = widget.servicioAuth ?? AuthService();
    _cargar(inicial: true);
  }

  Future<void> _cargar({bool inicial = false}) async {
    if (inicial) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    try {
      final sesion = await _auth.sesionActual();
      final cid = sesion?.usuario.id ?? '';
      if (cid.isEmpty) throw Exception('Inicia sesión para ver tu historial.');
      final h = await _srv.historial(
        clienteId: cid,
        limit: _limite,
        offset: inicial ? 0 : _offset,
      );
      if (!mounted) return;
      setState(() {
        if (inicial) {
          _items = h.items;
          _offset = h.items.length;
        } else {
          _items.addAll(h.items);
          _offset += h.items.length;
        }
        _hayMas = _offset < h.total && h.items.length >= _limite;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (inicial) {
          _error = e.toString().replaceAll('Exception: ', '');
          _cargando = false;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const VistaCarga(mensaje: 'Buscando tus compras…');
    if (_error != null) {
      return VistaError(
          mensaje: _error!, onReintentar: () => _cargar(inicial: true));
    }
    if (_items.isEmpty) {
      return VistaVacia(
        icono: Icons.shopping_bag_outlined,
        titulo: 'Aún no tienes compras',
        detalle:
            'Cuando compres en tienda, aquí verás el detalle de tus comprobantes.',
        accionTexto: 'Actualizar',
        onAccion: () => _cargar(inicial: true),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _cargar(inicial: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
        itemCount: _items.length + (_hayMas ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i >= _items.length) {
            _cargar();
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final c = _items[i];
          return Card(
            child: ExpansionTile(
              title: Text(
                'Compra ${c.numero}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${formatoFecha(c.creadaEn)} · ${c.totalPrendas} prenda(s)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                formatoPrecio(c.total),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              children: [
                for (final d in c.detalles)
                  ListTile(
                    dense: true,
                    title: Text('Cantidad: ${d.cantidad}'),
                    trailing: Text(formatoPrecio(
                        d.precioUnitario * d.cantidad - d.descuento)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
