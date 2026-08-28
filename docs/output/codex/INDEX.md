# Índice de decisiones Codex

## C-001 — Contexto del proyecto

**Input:** Leer los tres documentos de `docs/`.

**Output:** Bejuco es un MVP de comunicación de emergencia offline: paquetes persistentes que se propagan por BLE mediante *store-carry-forward* hasta un nodo con Internet.

**Decisión final:** Priorizar la prueba A → B → C con persistencia, deduplicación y tolerancia a desconexiones antes de ampliar funcionalidades.

## C-002 — Plataforma móvil

**Input:** Definir la implementación inicial.

**Output:** Los documentos prescriben Android nativo, Kotlin, Jetpack Compose, BLE y Room/SQLite; React Native e iOS quedan fuera del MVP.

**Decisión final:** El primer cliente es Android nativo.

## C-003 — Base técnica BLE

**Input:** Elegir el punto de partida para Android.

**Output:** BitChat Android es la referencia/base BLE. Debe conservarse como remoto `upstream` y registrarse el commit base con el tag `bitchat-base-v1`.

**Decisión final:** Partir de BitChat sin refactor masivo; evolucionar incrementalmente hacia paquetes de emergencia persistentes.

## C-004 — Repositorios

**Input:** Definir la topología de código.

**Output:** Los documentos definen repositorios independientes: `bejuco-android` y `bejuco-platform`; `bejuco-ios` es posterior al MVP. No se usa monorepo ni carpetas anidadas para esos productos.

**Decisión final:** `andresmolinasix/bejuco.online` representa actualmente la implementación Android (`bejuco-android`). `bejuco-platform` e `bejuco-ios` serán repositorios hermanos.

## C-005 — Límites de responsabilidad

**Input:** Separar responsabilidades entre repositorios.

**Output:** Android contiene BLE, persistencia, sincronización, relay y gateway cliente. Plataforma contiene protocolo canónico, test vectors, backend, dashboard, base de datos e infraestructura.

**Decisión final:** No crear `bejuco-platform/`, `bejuco-ios/` ni `mobile/android/` dentro del repositorio Android.

## C-006 — Hito de aceptación del MVP

**Input:** Establecer el primer resultado verificable.

**Output:** Un paquete M1 debe persistir en A, llegar a B, sobrevivir Bluetooth OFF/ON, y llegar de B a C aunque A ya no esté disponible.

**Decisión final:** El éxito inicial se mide por persistencia y propagación oportunista, no por cantidad de pantallas o funciones.

## C-007 — Inicialización del repositorio oficial

**Input:** Configurar y publicar el repositorio oficial de Bejuco Android.

**Output:** `main` fue publicada en `andresmolinasix/bejuco.online`; BitChat Android quedó integrado en la raíz como `upstream`. El tag `bitchat-base-v1` registra el commit base `4f828b5643ff87a5064c8d384d0a4cb64001d2b2`.

**Decisión final:** Usar `bejuco.online` como implementación Android actual, conservar BitChat como referencia técnica y aplicar commits convencionales.

**Verificación pendiente:** completar `./gradlew.bat assembleDebug --no-daemon`; Gradle se descargó e inició, pero no produjo un APK verificable durante la inicialización.

## C-008 — Verificación del build local

**Input:** Cerrar la verificación pendiente de C-007 ejecutando `./gradlew.bat assembleDebug --no-daemon`.

**Output:** El build falló inicialmente por dos dependencias del entorno ausentes: JDK 21 (el proyecto fija `languageVersion=21`; la máquina solo tenía JDK 11/17) y el Android SDK (`ANDROID_HOME` apuntaba a una ruta sin inicializar). Se instaló un JDK 21 (Eclipse Temurin) en el perfil de usuario y se completó la instalación del SDK vía el asistente de Android Studio (Platform 34 y 37, Build-Tools 37.0.0). Con ambos resueltos, `assembleDebug` terminó en `BUILD SUCCESSFUL` y generó los APKs de debug (`arm64-v8a`, `armeabi-v7a`, `x86`, `x86_64`, `universal`) en `app/build/outputs/apk/debug/`.

**Decisión final:** El build local queda verificado. Se descartó agregar el plugin `foojay-resolver-convention` para auto-provisionar el JDK porque `gradle/verification-metadata.xml` rechaza artefactos no confiados explícitamente; requerir JDK 21 y Android SDK Platform 37 / Build-Tools 37.0.0 preinstalados en la máquina de desarrollo queda como requisito documentado en vez de automatizarlo.

## C-009 — Implementación de ADR-0003: BejucoEnvelope y persistencia

**Input:** Implementar la decisión de ADR-0003 (`docs/adr/0003-persistent-store-carry-forward.md`): Room/SQLite como única fuente de verdad para mensajes de emergencia, separado de `mesh/`.

**Output:** `protocol/BejucoEnvelope.kt` (paquete Bejuco Protocol v1, identidad autocertificada vía `originId` derivado de `originPublicKey`, firma Ed25519 que excluye `hopCount` igual que `BitchatPacket` excluye `ttl`). `storage/EmergencyMessageDatabase.kt` — SQLite puro vía `SQLiteOpenHelper` (no Room: el proyecto usa dependency locking estricto y `verification-metadata.xml`, y los artefactos de Room/KSP no están confiados ahí; se optó por replicar el patrón ya probado de `services/ConversationRepository.kt` en vez de tocar esos archivos de seguridad). `emergency/EmergencyMessageRepository.kt` — límite de persistencia y validación, deduplica por `messageId`, nunca borra filas al expirar. Cubierto por 10 tests unitarios (firma, tampering, expiración, deduplicación, persistencia entre instancias del repositorio).

**Decisión final:** SQLite puro en vez de Room real, documentado como desviación deliberada de la letra de ADR-0003 (que nombra "Room") a favor de evitar fricción de build; el resto del diseño de la ADR se implementó tal cual se aceptó.

## C-010 — Relay entre `mesh/` y `emergency/`

**Input:** Conectar el transporte BLE existente (heredado de BitChat) con `EmergencyMessageRepository`, respetando que `mesh/` no debe interpretar paquetes de emergencia (docs/3 §5).

**Output:** Un tag de protocolo nuevo `MessageType.BEJUCO_ENVELOPE`. Dentro de `mesh/`: una interfaz de un solo método, `EmergencyPacketSink`, y una línea de despacho en `PacketProcessor` — ningún archivo de `mesh/` importa `BejucoEnvelope` ni `EmergencyMessageRepository`. `emergency/EmergencyRelay.kt` es el único punto que conoce ambos mundos: decodifica bytes entrantes y llama a `receiveEnvelope()`; arma, firma, persiste localmente y transmite un DISTRESS saliente vía `BluetoothMeshService.sendEmergencyEnvelope()` (calcado de `sendFileBroadcast()` existente). Cableado en `service/MeshServiceHolder.kt`, el único punto de construcción de `BluetoothMeshService`.

Verificado: compila limpio; la suite completa de tests (608 casos) da los mismos 22 fallos preexistentes con y sin este cambio (aislado con `git stash` sobre el mismo commit) — cero regresión atribuible a este trabajo.

**Decisión final:** Alcance limitado a `BluetoothMeshService` (transporte BLE, lo único que pide el MVP); `MeshCore`/Wi-Fi Aware queda sin tocar, fuera de alcance documentado.

**Verificación pendiente:** no existe todavía una prueba de integración real del relay (requeriría simular `BluetoothMeshService` completo) ni una prueba en hardware A → B → C sobre BLE físico — sigue siendo el hito de aceptación del MVP (C-006) sin demostrar.

## C-011 — Prueba en hardware: A → B confirmado

**Input:** Ejecutar la prueba física pendiente de C-010 con dos teléfonos Android reales.

**Output:** Se agregó un disparador de debug (`ui/debug/DebugSettingsSheet.kt`, sección "Bejuco emergency (test)") — botón "Send test DISTRESS" vía `MeshServiceHolder.emergencyRelay`, y una lista en vivo de `EmergencyMessageRepository.activeMessages()` — porque no existía ninguna forma de disparar un DISTRESS desde la UI.

Primer intento: el mesh no descubría ningún peer (`Mesh topology: No gossip yet`) pese a permisos correctos. Diagnóstico por `adb logcat` filtrado a los componentes BLE de `mesh/` encontró la causa raíz: `Scan failed: 2` (`SCAN_FAILED_APPLICATION_REGISTRATION_FAILED` de Android) repitiéndose en cada uno de 85 reintentos — la tabla de registros de escaneo BLE del sistema operativo estaba agotada, probablemente por los múltiples ciclos de conectar/desconectar de la sesión de pruebas. **Un reinicio completo de ambos teléfonos** (no solo apagar/prender Bluetooth) lo resolvió; esto es un problema de la pila BLE de Android/el heredado de BitChat, no de este código.

Tras el reinicio: `logcat` confirmó `🆕 New verified peer` y `Verified announce` entre ambos dispositivos. Se pulsó "Send test DISTRESS" en ambos teléfonos por separado; cada uno terminó mostrando mensajes con el `originId` del **otro** dispositivo en su lista de "Active emergency messages" — confirmando transferencia real, bidireccional, sobre BLE físico, con firma verificada y persistencia en SQLite del receptor.

**Decisión final:** A → B del hito C-006 queda demostrado en hardware. Se observó inestabilidad de conexión residual (ciclos de conectar/desconectar cada 3-8s, `error status 19`) que no impidió la entrega pero sigue siendo un problema heredado de BitChat sin investigar a fondo.

**Verificación pendiente:** (1) persistencia real — apagar Bluetooth o cerrar la app en el receptor y confirmar que el mensaje sigue en la lista; (2) B → C sin A presente, con un tercer dispositivo; (3) investigar la inestabilidad de conexión (`status 19`) si afecta la confiabilidad en un escenario de más de dos nodos.

## Referencia normativa

- Arquitectura: `docs/2-MAESTRO_DE_ARQUITECTURA.md`.
- Implementación Android: `docs/3-BEJUCO_IMPLEMENTACION_REPOSITORIO_V1.md`.
- Topología operativa: `docs/4-REPOSITORY_TOPOLOGY.md`.
