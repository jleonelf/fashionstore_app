import 'package:flutter/material.dart';

import '../../catalogo/models/catalogo_model.dart';
import '../../organizacion/models/organizacion_model.dart';
import '../models/reserva_model.dart';
import '../models/traslado_model.dart';
import '../../../core/network/api_exception.dart';
import '../../catalogo/services/catalogo_service.dart';
import '../services/reserva_service.dart';
import '../../organizacion/services/sucursal_service.dart';
import '../services/traslado_service.dart';
import '../../../core/ui/async_view.dart';
import '../../../core/ui/estado_chip.dart';
import '../../../core/ui/formato.dart';
import 'claves_reintento.dart';
import 'origen_helper.dart';

/// Detalle: código, vigencia, estados, cancelación permitida,
/// traslados y reintento de línea rechazada con otro origen.
class ReservaDetalleScreen extends StatefulWidget {
  final String reservaId;
  final ReservaService? servicioReservas;
  final TrasladoService? servicioTraslados;
  final SucursalService? servicioSucursales;
  final CatalogoService? servicioCatalogo;
  const ReservaDetalleScreen({
    super.key,
    required this.reservaId,
    this.servicioReservas,
    this.servicioTraslados,
    this.servicioSucursales,
    this.servicioCatalogo,
  });

  @override
  State<ReservaDetalleScreen> createState() => _ReservaDetalleScreenState();
}

class _ReservaDetalleScreenState extends State<ReservaDetalleScreen> {
  late final ReservaService _reservas;
  late final TrasladoService _traslados;
  late final SucursalService _sucursales;
  late final CatalogoService _catalogo;

  Reserva? _reserva;
  TrasladoLista? _trasladosLista;
  bool _cargando = true;
  String? _error;
  bool _cancelando = false;
  String? _reintentoLineaId;
  final ClavesReintento _clavesReintento = ClavesReintento();

  @override
  void initState() {
    super.initState();
    _reservas = widget.servicioReservas ?? ReservaService();
    _traslados = widget.servicioTraslados ?? TrasladoService();
    _sucursales = widget.servicioSucursales ?? SucursalService();
    _catalogo = widget.servicioCatalogo ?? CatalogoService();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await _reservas.obtener(widget.reservaId);
      // El seguimiento es de sólo lectura: se consulta aunque la reserva
      // haya terminado (traslado en tránsito tras cancelación/vencimiento).
      final quiereVer = AccionesReserva.puedeVerTraslados(
        r.estado,
        tieneTraslados: r.traslados.isNotEmpty,
        tieneLineasTraslado: r.detalles.any(
          (d) =>
              d.esperaTraslado ||
              d.estaRechazada ||
              d.cantidadPendienteTraslado > 0,
        ),
      );
      TrasladoLista? t;
      if (quiereVer || AccionesReserva.admiteSeguimientoHistorico(r)) {
        try {
          t = await _traslados.porReserva(r.id);
        } catch (_) {
          t = null;
        }
      }
      if (!mounted) return;
      setState(() {
        _reserva = r;
        _trasladosLista = t;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  Future<void> _cancelar() async {
    final r = _reserva;
    if (r == null || !r.permiteCancelar || _cancelando) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar reserva'),
        content: Text(
          'Se liberarán las ${r.totalPrendas} prenda(s) apartadas. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _cancelando = true);
    try {
      final actual = await _reservas.cancelar(r.id);
      if (!mounted) return;
      setState(() {
        _reserva = actual;
        _cancelando = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reserva cancelada.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _cancelando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _reintentar(DetalleReserva linea) async {
    final r = _reserva;
    if (r == null) return;
    // Cantidad pendiente de la línea rechazada (sin cambiar variante).
    final cantidadPendiente = linea.cantidadPendienteTraslado > 0
        ? linea.cantidadPendienteTraslado
        : linea.cantidadSolicitada;
    List<SucursalModel> sucs;
    List<DisponibilidadSucursal> disp;
    try {
      final resultados = await Future.wait([
        _sucursales.listar(),
        _catalogo.disponibilidad(linea.varianteId),
      ]);
      sucs = (resultados[0] as List<SucursalModel>)
          .where((s) => s.activa)
          .toList();
      disp = resultados[1] as List<DisponibilidadSucursal>;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return;
    }
    // Origen rechazado anteriormente (identificable desde el seguimiento).
    String? origenRechazado;
    final seg = _trasladosLista;
    if (seg != null) {
      final vistos = <TrasladoRecibido>[
        for (final t in seg.items)
          TrasladoRecibido(
            estado: t.estado,
            origenId: t.origenId,
            detalleIds: [
              for (final d in t.detalles)
                if (d.detalleReservaId != null) d.detalleReservaId!,
            ],
          ),
      ];
      origenRechazado = origenRechazadoParaLinea(
        traslados: vistos,
        detalleReservaId: linea.id,
      );
    }
    // Solo orígenes distintos al destino con stock suficiente; se excluye
    // el origen rechazado cuando sigue siendo identificable.
    final opciones = origenesValidosParaLinea(
      disponibilidad: disp,
      sucursales: sucs,
      destinoId: r.sucursalDestinoId,
      cantidadNecesaria: cantidadPendiente,
      excluirOrigenId: origenRechazado,
    );
    String? elegido;
    final ok = await showDialog<bool>(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('Pedir desde otra sucursal'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Necesitas $cantidadPendiente unidad(es) de esta prenda. '
                    'Elige el nuevo origen; no se cambia la variante ni la cantidad.',
                  ),
                  const SizedBox(height: 12),
                  if (opciones.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: const Text(
                        'No hay otra sucursal con suficientes unidades por ahora. Intenta más tarde o con otro destino.',
                        style: TextStyle(fontSize: 13),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: elegido,
                      decoration: const InputDecoration(
                        labelText: 'Nuevo origen',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final o in opciones)
                          DropdownMenuItem(
                            value: o.sucursal.id,
                            child: Text(
                              '${o.sucursal.nombre} (${o.disponible})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setLocal(() => elegido = v),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Volver'),
              ),
              ElevatedButton(
                onPressed: (elegido == null || opciones.isEmpty)
                    ? null
                    : () => Navigator.pop(ctx, true),
                child: const Text('Enviar solicitud'),
              ),
            ],
          ),
        );
      },
    );
    if (ok != true || elegido == null) return;
    setState(() => _reintentoLineaId = linea.id);
    try {
      // Clave estable por línea+origen; si el usuario cambia el origen
      // después de un conflicto de payload se genera una nueva.
      final clave = _clavesReintento.clavePara(
        lineaId: linea.id,
        origenId: elegido!,
      );
      await _traslados.reintentarLinea(
        detalleReservaId: linea.id,
        nuevoOrigenId: elegido!,
        claveIdempotencia: clave,
      );
      if (!mounted) return;
      setState(() => _reintentoLineaId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Solicitud enviada. Te avisaremos su estado.')),
      );
      _cargar();
    } catch (e) {
      if (!mounted) return;
      // 409 por reutilizar la clave con otro payload: descartarla para que
      // el siguiente intento (mismo u otro origen) use una clave nueva.
      if (esConflictoIdempotencia(e)) {
        _clavesReintento.invalidarPorConflicto(linea.id);
      }
      setState(() => _reintentoLineaId = null);
      final msg = e is ApiException ? e.mensaje : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de reserva')),
      body: _cargando
          ? const VistaCarga(mensaje: 'Cargando tu reserva…')
          : _error != null
              ? VistaError(mensaje: _error!, onReintentar: _cargar)
              : _contenido(),
    );
  }

  Widget _contenido() {
    final r = _reserva!;
    return RefreshIndicator(
      onRefresh: _cargar,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            r.codigo,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        EstadoChip.reserva(r.estadoLegible, r.estado),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Muestra este código al llegar a tienda.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const Divider(height: 20),
                    _fila('Vigencia', textoVigencia(r.venceEn)),
                    _fila('Prendas', '${r.totalPrendas}'),
                    if (r.fechaVisita != null)
                      _fila(
                          'Visita prevista', formatoFechaCorta(r.fechaVisita)),
                    if ((r.observacion ?? '').isNotEmpty)
                      _fila('Comentario', r.observacion!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text('Prendas apartadas',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 6),
            for (final d in r.detalles)
              Card(
                child: ListTile(
                  title: Text(
                    'Cantidad: ${d.cantidadSolicitada}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    d.estadoLegible,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: AccionesReserva.puedeReintentarLinea(
                    estadoReserva: r.estado,
                    estadoLinea: d.estadoLinea,
                  )
                      ? (_reintentoLineaId == d.id
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : TextButton(
                              onPressed: () => _reintentar(d),
                              child: const Text('Pedir de otro origen'),
                            ))
                      : null,
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(
                  child: Text('Traslados',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                if (r.estado == 'CANCELADA' || r.estado == 'VENCIDA')
                  const Text(
                    'Solo lectura',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (_trasladosLista == null)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                      'Aún no hay traslados para esta reserva, o no pudimos cargarlos. Desliza para actualizar.'),
                ),
              )
            else if (_trasladosLista!.items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                      'Todas tus prendas estaban en la sucursal destino. No se necesitó traslado.'),
                ),
              )
            else
              for (final t in _trasladosLista!.items)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.local_shipping_outlined),
                    title: Text(t.estadoLegible,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '${t.detalles.fold(0, (a, e) => a + e.cantidad)} prenda(s) en movimiento',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: EstadoChip.traslado(t.estadoLegible, t.estado),
                  ),
                ),
            const SizedBox(height: 16),
            if (r.permiteCancelar)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _cancelando ? null : _cancelar,
                  icon: _cancelando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cancel_outlined),
                  label: Text(_cancelando ? 'Cancelando…' : 'Cancelar reserva'),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    r.estado == 'CANCELADA' || r.estado == 'VENCIDA'
                        ? 'Esta reserva ya finalizó y no admite cambios.'
                        : 'En este estado la reserva la gestiona el personal de tienda.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fila(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(titulo, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(valor,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
