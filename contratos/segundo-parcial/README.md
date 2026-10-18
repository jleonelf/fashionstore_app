# Contrato del segundo parcial — Flutter cliente

**Versión propuesta: 0.1.0.** Las rutas nuevas descritas aquí aún no son OpenAPI real. La carpeta es autónoma dentro de `app-movil` para que se pueda compartir o clonar por separado.

## Contenido

- [interfaz.json](interfaz.json): copia fijada del contrato común cuyo origen está en `backend`.
- [operacion.schema.json](operacion.schema.json) y [resultado.schema.json](resultado.schema.json): esquemas de la cola y sus resultados.
- [compartido.md](compartido.md): identidad, sincronización, dinero y estados.
- [flutter.md](flutter.md): persistencia SQLite, compra/reserva diferidas, Stripe online y FCM.
- [integracion.md](integracion.md): contratos funcionales de todos los módulos relacionados.
- [payloads.md](payloads.md): ejemplos de mensajes para consumidores y dobles de prueba.
- [trazabilidad-cu.md](trazabilidad-cu.md): cambios de CU01–CU25 y responsabilidades de CU26–CU37.
- [flujo-trabajo.md](flujo-trabajo.md): entregas, PRs y coordinación con backend y web.
- [version.json](version.json): versión y SHA-256 de los tres JSON comunes.

Flutter es exclusivamente cliente. No implementa caja, venta de contado ni roles administrativos. Puede avanzar en un PR propio citando la versión del contrato y el PR del backend. Los consumidores se preparan con respuestas simuladas basadas en `interfaz.json`; la integración final se valida contra OpenAPI real y Android físico para push y probador. Los pendientes locales conservan su `version_esquema` y se migran de forma explícita si el contrato cambia.

Las tres copias comunes deben tener idéntica versión y hash. Proponer cambios de mensajes en backend, propagar a los tres repositorios y revisar compatibilidad antes de fusionar. Métodos y funciones nuevos en español, `camelCase`, salvo firmas obligatorias de SDK/framework.
