/// Modelos para el registro de dispositivos móviles y bandeja de avisos push (E2).
class DispositivoRegistroModel {
  final String id;
  final String dispositivoId;
  final String canal;
  final String estado;
  final String creadoEn;

  DispositivoRegistroModel({
    required this.id,
    required this.dispositivoId,
    required this.canal,
    required this.estado,
    required this.creadoEn,
  });

  factory DispositivoRegistroModel.fromJson(Map<String, dynamic> j) {
    return DispositivoRegistroModel(
      id: '${j['id'] ?? ''}',
      dispositivoId: '${j['dispositivo_id'] ?? ''}',
      canal: '${j['canal'] ?? 'FLUTTER'}',
      estado: '${j['estado'] ?? 'ACTIVO'}',
      creadoEn: '${j['creado_en'] ?? ''}',
    );
  }
}

class NotificacionAvisoModel {
  final String id;
  final String tipo;
  final String titulo;
  final String cuerpo;
  final String? recursoTipo;
  final String? recursoId;
  final String creadaEn;
  final String? leidaEn;

  NotificacionAvisoModel({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.cuerpo,
    this.recursoTipo,
    this.recursoId,
    required this.creadaEn,
    this.leidaEn,
  });

  bool get estaLeida => leidaEn != null && leidaEn!.isNotEmpty;

  factory NotificacionAvisoModel.fromJson(Map<String, dynamic> j) {
    return NotificacionAvisoModel(
      id: '${j['id'] ?? ''}',
      tipo: '${j['tipo'] ?? ''}',
      titulo: '${j['titulo'] ?? ''}',
      cuerpo: '${j['cuerpo'] ?? ''}',
      recursoTipo: j['recurso_tipo'] as String?,
      recursoId: j['recurso_id'] as String?,
      creadaEn: '${j['creada_en'] ?? ''}',
      leidaEn: j['leida_en'] as String?,
    );
  }
}
