import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/dispositivo_helper.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/storage/local_database_service.dart';
import '../models/caja_model.dart';

/// Servicio de Caja Offline Móvil (CU06 / CU07) para personal autorizado (Cajeros).
///
/// Integra persistencia durable en SQLite vía [LocalDatabaseService] para turno activo,
/// cupos autorizados/consumidos, ventas físicas offline y comprobantes locales,
/// garantizando restauración transparente tras reinicio y aislamiento estricto por empresa.
class CajaService {
  final ApiClient _api;
  final SessionManager _sesiones;
  final LocalDatabaseService _storage;

  SessionManager get sesiones => _sesiones;
  LocalDatabaseService get storage => _storage;
  ApiClient get api => _api;

  TurnoHabilitacionModel? _turnoActivoMemoria;
  final List<VentaOfflineCrearModel> _colaVentasMemoria = [];

  CajaService({
    ApiClient? api,
    SessionManager? sesiones,
    LocalDatabaseService? storage,
  })  : _sesiones = sesiones ?? SessionManager(),
        _storage = storage ?? LocalDatabaseService(),
        _api = api ?? ApiClient(sesiones: sesiones ?? SessionManager());

  Future<Map<String, String>> _obtenerContexto() async {
    final s = await _sesiones.leerValida();
    String dispId = '';
    try {
      dispId = await DispositivoHelper.obtenerDispositivoId();
    } catch (_) {}
    return {
      'empresa_id': s?.usuario.empresaId ?? '',
      'usuario_id': s?.usuario.usuarioId ?? s?.usuario.id ?? '',
      'dispositivo_id': dispId,
    };
  }

  // --- Restauración Transparente tras Reinicio (CU06 / CU07) ---
  Future<void> restaurarDesdeStorage({
    String? empresaId,
    String? dispositivoId,
    String? usuarioId,
  }) async {
    final ctx = await _obtenerContexto();
    final eId = empresaId ?? ctx['empresa_id'] ?? '';
    final dId = dispositivoId ?? ctx['dispositivo_id'] ?? '';
    final uId = usuarioId ?? ctx['usuario_id'] ?? '';

    if (eId.isEmpty) return;

    // 1. Restaurar turno activo desde SQLite con aislamiento por empresa
    var turno = await _storage.obtenerTurnoActivoLocal(
      empresaId: eId,
      dispositivoId: dId.isNotEmpty ? dId : null,
      usuarioId: uId.isNotEmpty ? uId : null,
    );
    turno ??= await _storage.obtenerTurnoActivoLocal(
      empresaId: eId,
    );
    _turnoActivoMemoria = turno;

    // 2. Restaurar ventas offline pendientes
    var pendientes = await _storage.listarVentasOfflinePendientes(
      empresaId: eId,
      turnoId: turno?.turnoId,
      usuarioId: uId.isNotEmpty ? uId : null,
      dispositivoId: dId.isNotEmpty ? dId : null,
    );
    if (pendientes.isEmpty && turno != null) {
      pendientes = await _storage.listarVentasOfflinePendientes(
        empresaId: eId,
        turnoId: turno.turnoId,
      );
    }
    _colaVentasMemoria.clear();
    _colaVentasMemoria.addAll(pendientes);
  }

  // --- CU06: Habilitar Turno Online ---
  Future<TurnoHabilitacionModel> habilitarTurno(TurnoCrearModel dto) async {
    final ctx = await _obtenerContexto();
    final eId = ctx['empresa_id'] ?? '';
    final uId = ctx['usuario_id'] ?? '';

    // Validar que empresaId esté presente y no vacío antes de proceder
    if (eId.isEmpty) {
      throw Exception(
          'No se puede habilitar turno: no hay empresa activa en la sesión.');
    }

    final key = const Uuid().v4();
    final turno = await _api.post(
      '/cajas/turnos',
      cuerpo: dto.toJson(),
      idempotencyKey: key,
      convertir: (j) =>
          TurnoHabilitacionModel.fromJson(j as Map<String, dynamic>),
    );

    // Guardar primero en SQLite con persistencia transaccional durable ANTES de poner en memoria.
    // Si SQLite falla, NO asignar a memoria para impedir cobros sobre turnos no durables.
    await _storage.guardarTurnoActivoLocal(
      turno,
      empresaId: eId,
      usuarioId: uId.isNotEmpty ? uId : turno.cajeroId,
    );

    _turnoActivoMemoria = turno;

    return turno;
  }

  // --- CU06: Consultar Turno Activo ---
  Future<TurnoHabilitacionModel?> consultarTurnoActivo(
      {String? dispositivoId}) async {
    final ctx = await _obtenerContexto();
    final dispId = dispositivoId ?? ctx['dispositivo_id'];
    final eId = ctx['empresa_id'] ?? '';
    final uId = ctx['usuario_id'] ?? '';

    try {
      final query = (dispId != null && dispId.isNotEmpty)
          ? {'dispositivo_id': dispId}
          : null;
      final turno = await _api.get(
        '/cajas/turnos/activo',
        query: query,
        convertir: (j) => j == null
            ? null
            : TurnoHabilitacionModel.fromJson(j as Map<String, dynamic>),
      );
      if (turno != null) {
        if (eId.isNotEmpty) {
          await _storage.guardarTurnoActivoLocal(turno,
              empresaId: eId, usuarioId: uId);
        }
        _turnoActivoMemoria = turno;
      } else {
        // Si el servidor devuelve null (el turno fue cerrado remotamente o ya no existe activo):
        // NO sobrescribir inmediatamente _turnoActivoMemoria con null antes de limpiar SQLite.
        // Obtener el ID del turno en memoria o empresaId, ejecutar _storage.limpiarTurnoActivoLocal
        // (e invalidar SQLite para esa empresa), y SOLO entonces limpiar _turnoActivoMemoria = null.
        final turnoIdAnterior = _turnoActivoMemoria?.turnoId ?? '';
        await _storage.limpiarTurnoActivoLocal(
          turnoIdAnterior,
          empresaId: eId.isNotEmpty ? eId : null,
        );
        _turnoActivoMemoria = null;
      }
      return turno;
    } catch (_) {
      // Sin conexión: restaurar de SQLite
      if (_turnoActivoMemoria == null && eId.isNotEmpty) {
        await restaurarDesdeStorage(
          empresaId: eId,
          dispositivoId: dispId,
          usuarioId: uId,
        );
      }
      return _turnoActivoMemoria;
    }
  }

  /// Consulta el balance autorizado completo de un turno en conciliación.
  /// Se usa después de ventas tardías o de una resolución parcial para que
  /// la pantalla no calcule cupos desde una copia anterior.
  Future<TurnoHabilitacionModel> consultarTurno(String turnoId) async {
    final turno = await _api.get<TurnoHabilitacionModel>(
      '/cajas/turnos/$turnoId',
      convertir: (j) =>
          TurnoHabilitacionModel.fromJson(j as Map<String, dynamic>),
    );
    final ctx = await _obtenerContexto();
    final empresaId = ctx['empresa_id'] ?? '';
    final usuarioId = ctx['usuario_id'] ?? '';
    if (empresaId.isEmpty) {
      throw Exception('No se pudo confirmar la empresa del turno consultado.');
    }
    await _storage.guardarTurnoActivoLocal(
      turno,
      empresaId: empresaId,
      usuarioId: usuarioId,
    );
    _turnoActivoMemoria = turno;
    return turno;
  }

  // --- CU07: Registrar / Sincronizar Venta Offline en Efectivo con Backend ---
  Future<VentaOfflineResultadoModel> registrarVentaOffline(
    String turnoId,
    VentaOfflineCrearModel dto,
  ) async {
    final resultado = await _api.post(
      '/cajas/turnos/$turnoId/ventas',
      cuerpo: dto.toJson(),
      convertir: (j) =>
          VentaOfflineResultadoModel.fromJson(j as Map<String, dynamic>),
    );

    // Actualizar en SQLite
    await _storage.marcarVentaOfflineSincronizada(
      dto.operacionId,
      resultadoJson: {
        'venta_id': resultado.ventaId,
        'numero': resultado.numero,
        'comprobante_id': resultado.comprobanteId,
        'recibida_central_en': resultado.recibidaCentralEn,
      },
    );

    // Sincronizar el cupo en memoria con el estado real persistido en SQLite/servidor.
    // NO volver a sumar linea.cantidad en memoria para ventas previamente cobradas.
    await sincronizarCuposMemoriaDesdeStorage(turnoId);

    return resultado;
  }

  // --- CU06 / CU07: Cerrar Turno ---
  Future<TurnoCerradoModel> cerrarTurno(
    String turnoId,
    TurnoCerrarModel dto,
  ) async {
    final cerrado = await _api.post(
      '/cajas/turnos/$turnoId/cerrar',
      cuerpo: dto.toJson(),
      convertir: (j) => TurnoCerradoModel.fromJson(j as Map<String, dynamic>),
    );

    if (cerrado.estado == 'CERRADO') {
      _turnoActivoMemoria = null;
      _colaVentasMemoria.clear();
      await _storage.limpiarTurnoActivoLocal(turnoId);
    } else if (cerrado.estado == 'CONCILIACION' &&
        _turnoActivoMemoria != null) {
      _turnoActivoMemoria!.estado = 'CONCILIACION';
      await _storage.actualizarEstadoTurnoLocal(
        turnoId,
        'CONCILIACION',
        revision: cerrado.revision,
      );
    }

    return cerrado;
  }

  // --- CU06: Recuperar Turno Perdido ---
  Future<Map<String, dynamic>> recuperarTurno(
    String turnoId, {
    required int revision,
    required String motivo,
  }) async {
    final res = await _api.post(
      '/cajas/turnos/$turnoId/recuperar',
      cuerpo: {
        'revision': revision,
        'motivo': motivo,
      },
      convertir: (j) => (j as Map).cast<String, dynamic>(),
    );

    _turnoActivoMemoria = null;
    await _storage.limpiarTurnoActivoLocal(turnoId);
    return res;
  }

  /// Obtiene la última secuencia local y total de operaciones registradas para el turno.
  Future<Map<String, int>> obtenerEstadisticasVentasTurno(String turnoId) {
    return _storage.obtenerEstadisticasVentasCaja(turnoId);
  }

  // --- Métodos locales para funcionamiento offline en dispositivo ---
  TurnoHabilitacionModel? get turnoActivoLocal => _turnoActivoMemoria;

  void fijarTurnoLocal(TurnoHabilitacionModel turno) {
    _turnoActivoMemoria = turno;
    _persistirTurnoLocalAsync(turno);
  }

  Future<void> fijarYPersistirTurnoLocal(
    TurnoHabilitacionModel turno, {
    String? empresaId,
    String? usuarioId,
  }) async {
    final ctx = await _obtenerContexto();
    final eId = empresaId ?? ctx['empresa_id'] ?? '';
    final uId = usuarioId ?? ctx['usuario_id'] ?? turno.cajeroId;
    if (eId.isEmpty) {
      throw Exception('No se puede registrar turno sin empresa activa.');
    }
    // Guardar primero en SQLite de forma durable antes de poner en memoria
    await _storage.guardarTurnoActivoLocal(turno,
        empresaId: eId, usuarioId: uId);
    _turnoActivoMemoria = turno;
  }

  /// Registro atómico y comprobante inmediato para venta física offline en efectivo (CU07)
  Future<ComprobanteLocalModel> registrarVentaFisicaOffline({
    required List<VentaOfflineLineaModel> lineas,
    required double totalBob,
    required double efectivoRecibidoBob,
    required double cambioEntregadoBob,
    String? clienteId,
  }) async {
    final turno = _turnoActivoMemoria;
    if (turno == null) {
      throw Exception('No hay turno de caja activo para cobrar ventas.');
    }

    final ctx = await _obtenerContexto();
    final empresaId = ctx['empresa_id'] ?? '';
    final usuarioId = ctx['usuario_id'] ?? turno.cajeroId;
    final dispositivoId = turno.dispositivoId.isNotEmpty
        ? turno.dispositivoId
        : (ctx['dispositivo_id'] ?? 'caja-local');

    final operacionId = const Uuid().v4();
    final comprobanteId = const Uuid().v4();
    final ahoraUtc = DateTime.now().toUtc().toIso8601String();
    final numSecuencia = await _storage.obtenerSiguienteSecuenciaVentaCaja(
      turnoId: turno.turnoId,
      dispositivoId: dispositivoId,
    );

    final venta = VentaOfflineCrearModel(
      operacionId: operacionId,
      secuenciaLocal: numSecuencia,
      vendidaLocalEn: ahoraUtc,
      entregadaLocalEn: ahoraUtc,
      versionPrecios: turno.versionPrecios,
      lineas: lineas,
      totalBob: totalBob,
      efectivoRecibidoBob: efectivoRecibidoBob,
      cambioEntregadoBob: cambioEntregadoBob,
      clienteId: clienteId,
    );

    final numeroComp = 'COMP-LOC-${operacionId.substring(0, 8).toUpperCase()}';
    final comprobante = ComprobanteLocalModel(
      comprobanteId: comprobanteId,
      operacionId: operacionId,
      turnoId: turno.turnoId,
      empresaId: empresaId,
      numeroComprobante: numeroComp,
      totalBob: totalBob,
      efectivoRecibidoBob: efectivoRecibidoBob,
      cambioBob: cambioEntregadoBob,
      emitidoEn: ahoraUtc,
      lineas: lineas.map((l) => l.toJson()).toList(),
    );

    // 1. Guardar de forma transaccional durable en SQLite
    await _storage.guardarVentaOfflineDurable(
      turnoId: turno.turnoId,
      venta: venta,
      empresaId: empresaId,
      usuarioId: usuarioId,
      dispositivoId: dispositivoId,
      comprobante: comprobante,
    );

    // 2. Actualizar estado en memoria
    if (!_colaVentasMemoria.any((v) => v.operacionId == operacionId)) {
      _colaVentasMemoria.add(venta);
    }
    for (final l in lineas) {
      final cupo =
          turno.cupos.where((c) => c.varianteId == l.varianteId).firstOrNull;
      if (cupo != null) {
        cupo.consumido += l.cantidad;
      }
    }

    return comprobante;
  }

  void encolarVentaOffline(VentaOfflineCrearModel venta) {
    if (!_colaVentasMemoria
        .any((item) => item.operacionId == venta.operacionId)) {
      _colaVentasMemoria.add(venta);
    }

    // Descontar cupo localmente en memoria
    if (_turnoActivoMemoria != null) {
      for (final l in venta.lineas) {
        final cupo = _turnoActivoMemoria!.cupos
            .where((c) => c.varianteId == l.varianteId)
            .firstOrNull;
        if (cupo != null) {
          cupo.consumido += l.cantidad;
        }
      }
    }

    // Persistir de forma durable en SQLite asíncronamente
    _persistirVentaOfflineAsync(venta);
  }

  Future<void> _persistirTurnoLocalAsync(TurnoHabilitacionModel turno) async {
    try {
      final ctx = await _obtenerContexto();
      final eId = ctx['empresa_id'] ?? '';
      final uId = ctx['usuario_id'] ?? turno.cajeroId;
      if (eId.isNotEmpty) {
        await _storage.guardarTurnoActivoLocal(turno,
            empresaId: eId, usuarioId: uId);
      }
    } catch (_) {}
  }

  Future<void> _persistirVentaOfflineAsync(VentaOfflineCrearModel venta) async {
    try {
      final turno = _turnoActivoMemoria;
      if (turno == null) return;
      final ctx = await _obtenerContexto();
      final eId = ctx['empresa_id'] ?? '';
      final uId = ctx['usuario_id'] ?? turno.cajeroId;
      final dId = turno.dispositivoId.isNotEmpty
          ? turno.dispositivoId
          : (ctx['dispositivo_id'] ?? 'caja-local');
      if (eId.isEmpty) return;

      final comprobante = ComprobanteLocalModel(
        comprobanteId: const Uuid().v4(),
        operacionId: venta.operacionId,
        turnoId: turno.turnoId,
        empresaId: eId,
        numeroComprobante:
            'COMP-LOC-${venta.operacionId.substring(0, 8).toUpperCase()}',
        totalBob: venta.totalBob,
        efectivoRecibidoBob: venta.efectivoRecibidoBob,
        cambioBob: venta.cambioEntregadoBob,
        emitidoEn: venta.vendidaLocalEn,
        lineas: venta.lineas.map((l) => l.toJson()).toList(),
      );

      await _storage.guardarVentaOfflineDurable(
        turnoId: turno.turnoId,
        venta: venta,
        empresaId: eId,
        usuarioId: uId,
        dispositivoId: dId,
        comprobante: comprobante,
      );
    } catch (_) {}
  }

  List<VentaOfflineCrearModel> get ventasOfflinePendientes =>
      List.unmodifiable(_colaVentasMemoria);

  Future<List<ComprobanteLocalModel>> listarComprobantesLocales(
      String turnoId) {
    return _storage.listarComprobantesLocales(turnoId);
  }

  Future<int> sincronizarVentasPendientes(String turnoId) async {
    final ctx = await _obtenerContexto();
    final eId = ctx['empresa_id'] ?? '';

    // Cargar pendientes desde SQLite para garantizar que ninguna quede omitida tras reinicio
    List<VentaOfflineCrearModel> pendientes;
    if (eId.isNotEmpty) {
      pendientes = await _storage.listarVentasOfflinePendientes(
        empresaId: eId,
        turnoId: turnoId,
      );
    } else {
      pendientes = List<VentaOfflineCrearModel>.from(_colaVentasMemoria);
    }

    if (pendientes.isEmpty) return 0;

    int sincronizadas = 0;
    for (final v in pendientes) {
      try {
        // Enviar con el operacion_id UUID original estricto
        await registrarVentaOffline(turnoId, v);
        _colaVentasMemoria
            .removeWhere((item) => item.operacionId == v.operacionId);
        sincronizadas++;
      } catch (_) {
        // Si no hay conexión o falla transitoriamente, permanece en la cola durable
      }
    }

    // Sincronizar cupos en memoria tras completar lote de sincronización
    await sincronizarCuposMemoriaDesdeStorage(turnoId);

    return sincronizadas;
  }

  /// Sincroniza los cupos en memoria con el estado real persistido en SQLite.
  Future<void> sincronizarCuposMemoriaDesdeStorage(String turnoId) async {
    if (_turnoActivoMemoria != null &&
        _turnoActivoMemoria!.turnoId == turnoId) {
      try {
        final cuposActualizados =
            await _storage.obtenerCuposTurnoLocal(turnoId);
        if (cuposActualizados.isNotEmpty) {
          for (final cDb in cuposActualizados) {
            final cMem = _turnoActivoMemoria!.cupos
                .where((x) => x.varianteId == cDb.varianteId)
                .firstOrNull;
            if (cMem != null) {
              cMem.consumido = cDb.consumido;
              cMem.liberado = cDb.liberado;
            }
          }
        }
      } catch (_) {}
    }
  }
}
