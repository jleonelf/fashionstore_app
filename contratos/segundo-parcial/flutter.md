# Contrato Flutter cliente y SQLite

**Estado:** diseño de cliente móvil previo a implementación. Comparte comandos/resultados con [compartido.md](compartido.md), no la persistencia física de Angular.

## Alcance y almacenamiento

Flutter es exclusivamente cliente: catálogo descargado, reserva propia, carrito/solicitud de compra diferida, pendientes/resultados, pago Stripe **online**, saldo consultable/utilizable online, notificaciones FCM y probador Decart existente. No incluye roles de personal, caja, efectivo ni venta de contado offline; esta diferencia con el texto académico se registra en trazabilidad.

SQLite tendrá tablas o estructuras equivalentes versionadas para catálogo/variantes por empresa, copia de sucursales permitidas, identidad local mínima, solicitudes y líneas, cola de operaciones, resultados/notificaciones y metadatos de sincronización. No guardar tarjeta ni clave permanente de proveedores. Cada fila privada se vincula a empresa y usuario; logout/cambio de cuenta oculta datos propios y no los sincroniza con otra identidad.

La sesión privada local vale ocho horas desde último login online. Catálogo público descargado continúa visible sin esa sesión. Al reautenticar, la app recupera pendientes propios y backend revalida empresa, plan, stock, precio y vigencia. Una escritura local confirmada debe sobrevivir a cierre/reinicio normal.

## Reserva, compra y avisos

| Acción | Comportamiento móvil |
|---|---|
| Crear reserva sin red | Guardar UUID, creación local, sucursal, visita y líneas; mostrar pendiente sin prometer stock. |
| Crear compra sin red | Guardar solicitud y líneas; no crear intención Stripe ni reservar stock desde el teléfono. |
| Recuperar Internet | Enviar operaciones propias con UUID estable; consultar resultado si se perdió respuesta; presentar falta de stock, precio cambiado o aceptación. |
| Pagar | Solo online, después de apartado central y aceptación del BOB/USD mostrado. Abrir flujo Stripe existente y consultar estado final; no inferir éxito de la navegación de retorno. |
| Avisar | Guardar bandeja propia y recibir push FCM Android cuando haya permiso y servicio; al tocarlo, autenticar y consultar estado. |

La sincronización en segundo plano depende del sistema operativo; debe existir recuperación al abrir y reintento manual. No prometer ejecución instantánea estando cerrada. El probador existente conserva Lucy 2.5 y su puente Android oficial, con autorización por tenant; no rediseñarlo como parte de ML.

## Funciones nuevas en español y pruebas

Nombres sugeridos Dart: `guardarSolicitudLocal`, `sincronizarPendientes`, `consultarResultado`, `ocultarDatosPrivados`, `registrarTokenNotificacion`, `abrirPagoEnLinea`. Mantener firmas obligatorias de SDK como adaptadores y no renombrar silenciosamente servicios públicos existentes.

Pruebas de aceptación: reinicio sin conexión, sesión local vencida, cambio de usuario/empresa, solicitud de reserva vencida desde creación local, competencia por última unidad, precio nuevo, mismo UUID tras pérdida de respuesta, push concedido/denegado, pago exitoso/fallido/en verificación. Validar push y probador realtime final en Android físico. La app no debe declarar venta de contado móvil cumplida.
