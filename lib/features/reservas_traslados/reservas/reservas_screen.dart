import 'package:flutter/material.dart';

import '../models/reserva_model.dart';
import '../services/reserva_service.dart';
import '../../../core/ui/async_view.dart';
import '../../../core/ui/colores.dart';
import '../../../core/ui/estado_chip.dart';
import '../../../core/ui/formato.dart';
import 'bolsa_screen.dart';
import 'bolsa_store.dart';
import 'reserva_detalle_screen.dart';

/// Listado paginado de reservas propias.
class ReservasScreen extends StatefulWidget {
  final ReservaService? servicio;
  const ReservasScreen({super.key, this.servicio});

  @override
  State<ReservasScreen> createState() => _ReservasScreenState();
}

class _ReservasScreenState extends State<ReservasScreen> {
  late final ReservaService _srv;
  List<Reserva> _items = [];
  bool _cargando = true;
  String? _error;
  int _offset = 0;
  static const _limite = 20;
  bool _hayMas = true;

  @override
  void initState() {
    super.initState();
    _srv = widget.servicio ?? ReservaService();
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
      final lista = await _srv.listarMias(
        limit: _limite,
        offset: inicial ? 0 : _offset,
      );
      if (!mounted) return;
      setState(() {
        if (inicial) {
          _items = lista.items;
          _offset = lista.items.length;
        } else {
          _items.addAll(lista.items);
          _offset += lista.items.length;
        }
        _hayMas = _offset < lista.total && lista.items.length >= _limite;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (inicial) {
          _error = e.toString();
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: AnimatedBuilder(
            animation: BolsaStore.instancia,
            builder: (_, __) {
              final n = BolsaStore.instancia.totalPrendas;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.shopping_bag_outlined,
                      color: ColoresFS.brassStrong),
                  title: const Text('Mis prendas reservadas',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    n == 0
                        ? 'Tu bolsa para apartar y probar en tienda.'
                        : '$n prenda(s) listas para confirmar.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: n > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: ColoresFS.brassSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('$n',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: ColoresFS.brassStrong)),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BolsaScreen(
                          onReservaCreada: () => _cargar(inicial: true),
                        ),
                      ),
                    );
                    if (mounted) _cargar(inicial: true);
                  },
                ),
              );
            },
          ),
        ),
        Expanded(child: _lista()),
      ],
    );
  }

  Widget _lista() {
    if (_cargando) return const VistaCarga(mensaje: 'Buscando tus reservas…');
    if (_error != null) {
      return VistaError(
        mensaje: _error!,
        onReintentar: () => _cargar(inicial: true),
      );
    }
    if (_items.isEmpty) {
      return VistaVacia(
        icono: Icons.receipt_long_outlined,
        titulo: 'Aún no tienes reservas',
        detalle:
            'Cuando apartes prendas desde el catálogo, aquí verás su código, vigencia y estado.',
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
          final r = _items[i];
          return Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Reserva ${r.codigo}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  EstadoChip.reserva(r.estadoLegible, r.estado),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${r.totalPrendas} prenda(s) · ${textoVigencia(r.venceEn)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReservaDetalleScreen(reservaId: r.id),
                  ),
                );
                if (mounted) _cargar(inicial: true);
              },
            ),
          );
        },
      ),
    );
  }
}
