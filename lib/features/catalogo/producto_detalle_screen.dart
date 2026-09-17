import 'package:flutter/material.dart';

import '../../core/models/catalogo_model.dart';
import '../../core/services/catalogo_service.dart';
import '../../core/ui/async_view.dart';
import '../../core/ui/formato.dart';
import '../reservas/bolsa_store.dart';

/// Detalle de prenda: variantes por talla/color + disponibilidad por sucursal.
class ProductoDetalleScreen extends StatefulWidget {
  final Producto producto;
  const ProductoDetalleScreen({super.key, required this.producto});

  @override
  State<ProductoDetalleScreen> createState() => _ProductoDetalleScreenState();
}

class _ProductoDetalleScreenState extends State<ProductoDetalleScreen> {
  final _servicio = CatalogoService();
  List<Variante> _variantes = [];
  bool _cargando = true;
  String? _error;
  String? _varianteSel;
  List<DisponibilidadSucursal> _disponibilidad = [];
  bool _cargandoDisp = false;
  String? _errorDisp;
  int _cantidad = 1;

  @override
  void initState() {
    super.initState();
    _cargarVariantes();
  }

  Future<void> _cargarVariantes() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final vs = await _servicio.variantesPorProducto(widget.producto.id);
      if (!mounted) return;
      setState(() {
        _variantes = vs.where((e) => e.activa).toList();
        _cargando = false;
        if (_variantes.isNotEmpty) {
          _varianteSel = _variantes.first.id;
          _cargarDisponibilidad(_variantes.first.id);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  Future<void> _cargarDisponibilidad(String varianteId) async {
    setState(() {
      _cargandoDisp = true;
      _errorDisp = null;
      _disponibilidad = [];
    });
    try {
      final d = await _servicio.disponibilidad(varianteId);
      if (!mounted) return;
      setState(() {
        _disponibilidad = d;
        _cargandoDisp = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorDisp = e.toString();
        _cargandoDisp = false;
      });
    }
  }

  Variante? get _sel {
    if (_varianteSel == null) return null;
    try {
      return _variantes.firstWhere((e) => e.id == _varianteSel);
    } catch (_) {
      return null;
    }
  }

  void _agregarABolsa() {
    final v = _sel;
    if (v == null) return;
    BolsaStore.instancia.agregar(
      varianteId: v.id,
      nombrePrenda: widget.producto.nombre,
      sku: v.sku,
      precio: v.precio,
      cantidad: _cantidad,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Agregamos $_cantidad prenda(s) a tu bolsa de reserva.'),
        action: SnackBarAction(
          label: 'Ver bolsa',
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.producto;
    return Scaffold(
      appBar: AppBar(title: Text(p.nombre, maxLines: 1)),
      body: _cargando
          ? const VistaCarga(mensaje: 'Cargando tallas y colores…')
          : _error != null
              ? VistaError(mensaje: _error!, onReintentar: _cargarVariantes)
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (p.imagenPrincipal.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            p.imagenPrincipal,
                            height: 260,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 160,
                              color: Colors.grey.shade100,
                              child: const Icon(Icons.checkroom, size: 56),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(p.nombre,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      if ((p.marca ?? '').isNotEmpty ||
                          (p.genero ?? '').isNotEmpty)
                        Text(
                          [p.marca, p.genero]
                              .where(
                                  (e) => e != null && e.toString().isNotEmpty)
                              .join(' · '),
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      const SizedBox(height: 6),
                      Text(formatoPrecio(p.precioBase),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800)),
                      if ((p.descripcion ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(p.descripcion!),
                      ],
                      const SizedBox(height: 16),
                      const Text('Talla y color',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      const Text(
                        'Elige la variante que quieres reservar.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      if (_variantes.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                                'Esta prenda no tiene variantes disponibles por el momento.'),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final v in _variantes)
                              ChoiceChip(
                                label: Text(v.sku),
                                selected: _varianteSel == v.id,
                                onSelected: (_) {
                                  setState(() {
                                    _varianteSel = v.id;
                                    _cantidad = 1;
                                  });
                                  _cargarDisponibilidad(v.id);
                                },
                              ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      const Text('Disponibilidad por sucursal',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      const Text(
                        'Te mostramos dónde hay unidades listas para apartar.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      if (_cargandoDisp)
                        const VistaCarga(mensaje: 'Consultando disponibilidad…')
                      else if (_errorDisp != null)
                        VistaError(
                          mensaje: _errorDisp!,
                          onReintentar: () =>
                              _cargarDisponibilidad(_varianteSel ?? ''),
                        )
                      else if (_disponibilidad.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Sin unidades disponibles en este momento. Puedes elegir otra variante o pedir traslado al confirmar tu bolsa.',
                            ),
                          ),
                        )
                      else
                        for (final d in _disponibilidad)
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.store_outlined),
                              title: Text(d.sucursalNombre,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                '${d.ciudadNombre} · ${d.disponible} disponible(s)',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text(
                                '${d.disponible}',
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
      bottomSheet: _cargando || _error != null || _variantes.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Quitar una',
                          onPressed: _cantidad > 1
                              ? () => setState(() => _cantidad--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('$_cantidad',
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w800)),
                        IconButton(
                          tooltip: 'Agregar una',
                          onPressed: () => setState(() => _cantidad++),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _agregarABolsa,
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: const Text('Agregar a la bolsa'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
