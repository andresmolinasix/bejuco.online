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

## Referencia normativa

- Arquitectura: `docs/2-MAESTRO_DE_ARQUITECTURA.md`.
- Implementación Android: `docs/3-BEJUCO_IMPLEMENTACION_REPOSITORIO_V1.md`.
- Topología operativa: `docs/4-REPOSITORY_TOPOLOGY.md`.

