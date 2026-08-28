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

## Referencia normativa

- Arquitectura: `docs/2-MAESTRO_DE_ARQUITECTURA.md`.
- Implementación Android: `docs/3-BEJUCO_IMPLEMENTACION_REPOSITORIO_V1.md`.
- Topología operativa: `docs/4-REPOSITORY_TOPOLOGY.md`.
