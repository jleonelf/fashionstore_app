# Guía de Auditoría: Notificaciones Push FCM en Android / Flutter (Puerta D)

**Fecha:** Noviembre 2026  
**Componente:** `app-movil` (FashionStore Flutter) & `backend` (FastAPI)  
**Módulo:** Identidad, Dispositivos y Outbox de Avisos Push (E2)  
**Estado:** Implementado, verificado y desacoplado de variables obligatorias.

---

## 1. Resumen Ejecutivo y Corrección de Defecto

En la **Auditoría 28** se identificó que el servicio móvil `notificacion_movil_service.dart` dependía estrictamente de `--dart-define=FCM_PUSH_TOKEN` o inyección manual, careciendo de un ciclo de vida reactivo con Firebase Messaging para obtención, renovación (`onTokenRefresh`) y recepción offline.

**Correcciones implementadas:**
1. **Eliminación de dependencia obligatoria:** `--dart-define=FCM_PUSH_TOKEN` ya no es requerido. La app gestiona el token de forma autónoma.
2. **Arquitectura desacoplada (`FcmAdapter`) e integración oficial FlutterFire:**
   - **Dependencias oficiales:** `firebase_core: 5.1.0` y `firebase_messaging: 17.0.1` configuradas en `pubspec.yaml` y resueltas localmente.
   - **`NativePlatformFcmAdapter`**: Conecta con Firebase Cloud Messaging mediante la API oficial (`Firebase.initializeApp()`, `FirebaseMessaging.instance`, `requestPermission()`, `getToken()`, `onTokenRefresh`, `FirebaseMessaging.onMessage`, `FirebaseMessaging.onBackgroundMessage` con handler `@pragma('vm:entry-point')` y `getInitialMessage()`).
   - **`SimulatedFcmAdapter`**: Permite pruebas unitarias y de integración en Windows/CI sin necesidad de emuladores ni hardware físico.
   - **Inyección por constructor:** `NotificacionMovilService({ApiClient? api, FcmAdapter? adapter})` permite inyección directa del doble de prueba en tiempo de ejecución o pruebas.
   - **Fallback limpio y descriptivo:** Si Firebase no está configurado (`google-services.json` ausente o sin Google Play Services), el servicio no colapsa; transiciona a `EstadoFcm.noConfigurado`, genera un token local persistido `sim-fcm-<dispositivo_id>` y continúa operando honestamente reportando su estado.
3. **Renovación automática (`onTokenRefresh`):** Escucha el evento de renovación de token de Firebase y lo sincroniza de inmediato con el backend central mediante `POST /api/v1/notificaciones/dispositivos`.
4. **Recepción en foreground, background y cold start:** Los mensajes push recibidos ingresan automáticamente en la bandeja offline local (`bandejaOffline`), permitiendo la consulta offline y la fusión sin duplicados con `GET /api/v1/notificaciones/bandeja`.
5. **Permisos y Manifiesto Android (`AndroidManifest.xml`):** Asegurados `POST_NOTIFICATIONS` (Android 13+ / API 33+), `INTERNET` y `WAKE_LOCK`. Se eliminó la entrada manual `<service android:name="com.google.firebase.messaging.FirebaseMessagingService" .../>` para evitar conflictos con la clase base abstracta de Android, delegando la declaración del receptor al plugin FlutterFire (`FlutterFirebaseMessagingService`) durante el merge automático de manifiestos.

---

## 2. Requisitos para Prueba en Dispositivo Android Físico

Para ejecutar una prueba de notificaciones push de extremo a extremo con entrega real en un dispositivo Android físico, se requieren las siguientes configuraciones (sin commitear credenciales privadas en el repositorio):

### 2.1. Archivo `google-services.json` del Cliente Android
Debe obtenerse desde la consola de Firebase del proyecto y colocarse exactamente en:
```
app-movil/android/app/google-services.json
```
*(Este archivo está ignorado en `.gitignore` para salvaguardar credenciales y tokens).*

#### Plantilla Sanitizada de Referencia (`google-services.json`):
```json
{
  "project_info": {
    "project_number": "123456789012",
    "project_id": "fashionstore-prod",
    "storage_bucket": "fashionstore-prod.firebasestorage.app"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:123456789012:android:abcdef0123456789",
        "android_client_info": {
          "package_name": "com.example.fashionstore_movil"
        }
      },
      "oauth_client": [],
      "api_key": [
        {
          "current_key": "AIzaSySanitizedClientApiKeyForAndroidPush123"
        }
      ],
      "services": {
        "appinvite_service": {
          "other_platform_oauth_client": []
        }
      }
    }
  ],
  "configuration_version": "1"
}
```

### 2.2. Credenciales del Servidor en Backend (`FCM_CREDENTIALS_JSON`)
El backend FastAPI despacha push mediante HTTP v1 de Google Cloud. Requiere la clave de cuenta de servicio de Google Cloud con el rol `Firebase Cloud Messaging API`:
- Variable de entorno en backend:
  ```env
  FCM_CREDENTIALS_JSON='{"type": "service_account", "project_id": "fashionstore-prod", "private_key_id": "...", "private_key": "...", "client_email": "firebase-adminsdk@fashionstore-prod.iam.gserviceaccount.com", ...}'
  ```
- Si la variable está ausente, el backend reporta honestamente `PushResult(exito=False, codigo="NO_CONFIGURADO")` sin revertir transacciones de venta ni generar falsos positivos.

---

## 3. Manifiesto y Permisos Android (`AndroidManifest.xml`)

Ubicación: `app-movil/android/app/src/main/AndroidManifest.xml`

### Permisos Declarados:
- `<uses-permission android:name="android.permission.INTERNET"/>`: Comunicación HTTP/REST con el backend.
- `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>`: Obligatorio en Android 13+ (API 33+) para desplegar notificaciones al usuario.
- `<uses-permission android:name="android.permission.WAKE_LOCK"/>`: Permite procesar el mensaje push entrante en segundo plano mientras la CPU está en reposo.

### Servicio Receptor Firebase en Segundo Plano:
El servicio receptor es provisto e inyectado automáticamente en el manifiesto final por el plugin oficial de FlutterFire (`io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService`) mediante el merge de Gradle.
> [!NOTE]
> Se eliminó la declaración explícita anterior de `<service android:name="com.google.firebase.messaging.FirebaseMessagingService" .../>` puesto que `FirebaseMessagingService` es una clase abstracta del SDK de Google Play Services; declararla directamente en el manifiesto causaba advertencias o excepciones de instanciación en runtime cuando el plugin oficial ya incorpora su propia implementación concreta.

---

## 4. Procedimiento de Verificación en Dispositivo Físico

1. **Conexión del Dispositivo:**
   ```bash
   adb devices
   ```
2. **Copiar `google-services.json`** en `app-movil/android/app/`.
3. **Compilar y desplegar:**
   ```bash
   cd app-movil
   flutter run -d <DEVICE_ID>
   ```
4. **Flujo en Pantalla:**
   - Al iniciar sesión, la app solicita permiso de notificaciones (diálogo del sistema Android).
   - Tras concederlo, `NotificacionMovilService.inicializar()` obtiene el token real de FCM de Google Play Services.
   - El token se envía automáticamente al backend:
     `POST /api/v1/notificaciones/dispositivos` con `{ "dispositivo_id": "<UUID>", "canal": "FLUTTER", "push_token": "<FCM_TOKEN>" }`.
5. **Prueba de Envío desde el Backend:**
   - Realizar una compra o liquidar una venta presencial Stripe Test.
   - El backend registra el evento en `comercial.eventos_outbox`.
   - Ejecutar el worker del outbox:
     `POST /api/v1/notificaciones/procesar-outbox`
   - El dispositivo Android físico recibe el push en la barra superior.
   - Al abrir la notificación, la app abre la pantalla correspondiente y marca la lectura mediante `PATCH /api/v1/notificaciones/bandeja/{id}/leer`.

---

## 5. Comportamiento en Entornos sin Firebase (Desarrollo / CI)

Si la app se ejecuta sin `google-services.json`, en emuladores sin Google Play Services o en suites de pruebas automatizadas:
- `estadoFcm`: `EstadoFcm.noConfigurado`.
- `tokenActual`: `sim-fcm-<dispositivo_id>` (fallback determinista y persistido).
- `ultimoDiagnostico`: Mensaje descriptivo informando el modo de contingencia.
- **Resultado:** Ningún error de inicialización, 0 excepciones no controladas y 100% de compatibilidad con pruebas unitarias offline.
