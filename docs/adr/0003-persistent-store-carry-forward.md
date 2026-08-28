# ADR-0003: Persistencia Room autoritativa para store-carry-forward

## Status
Accepted

## Context
`StoreForwardManager` (heredado de BitChat,
`app/src/main/java/com/bitchat/android/mesh/StoreForwardManager.kt`) cachea
paquetes exclusivamente en memoria (`Collections.synchronizedList`,
`ConcurrentHashMap`). No sobrevive cierre de app, process death ni reinicio
del dispositivo. Además, `cacheMessage()` descarta explícitamente los
mensajes dirigidos a `SpecialRecipients.BROADCAST` (línea 54) y solo cachea
mensajes con un `recipientID` conocido y válido.

Esto es incompatible con el criterio de aceptación del MVP (C-006,
`docs/output/codex/INDEX.md`): un paquete DISTRESS debe persistir en A,
llegar a B, sobrevivir Bluetooth OFF/ON, y llegar de B a C aunque A ya no
esté disponible.

La dirección — Room/SQLite, persistencia obligatoria, store-carry-forward —
ya está congelada como requisito en
`docs/3-BEJUCO_IMPLEMENTACION_REPOSITORIO_V1.md` (línea 403 y siguientes).
Esta ADR no decide *si* usar Room; decide *cómo* se integra con el mesh
existente, algo que los documentos normativos dejan abierto.

## Decision

**Room como única fuente de verdad.** No habrá dos rutas de escritura
independientes. Puede existir una caché en memoria, pero únicamente como
proyección reconstruible desde Room al arrancar — nunca con mutaciones
propias que Room no conozca.

**Separación estricta de responsabilidades.** `mesh/` sigue transportando
bytes ciegos; no aprende a interpretar `BejucoEnvelope` ni tipos de
emergencia, tal como exige `docs/3 §5`. La lógica nueva vive en un
`EmergencyMessageRepository` (persistencia) y un `EmergencyRelay`
(selección de qué reenviar), ambos por encima de `mesh/`, nunca dentro.

**Semántica de entrega explícita, no implícita.** Un envío B → C no
constituye entrega global. Un paquete permanece en Room hasta que:
- expira (`expiresAt` / `hopLimit` agotado según el protocolo), o
- se invalida (firma inválida, versión no soportada), o
- una regla explícita de ACK lo marque como resuelto.

Nunca se borra solo porque ya se envió a un peer.

**Validación antes de persistir.** Se valida versión de protocolo, TTL,
`hopLimit` y firma antes de escribir en Room. Un paquete inválido no se
persiste ni se relee.

**Esquema mínimo por fila:**
- `message_id` (PK, deduplicación vía `INSERT ... ON CONFLICT IGNORE`,
  mismo principio que el backend PostgreSQL descrito en
  `docs/2-MAESTRO_DE_ARQUITECTURA.md §5`)
- envelope serializado
- estado de propagación
- `receivedAt`

**Restauración tras reinicio.** Al iniciar la app o el foreground service,
la cola de propagación se reconstruye leyendo Room, no memoria. Esto
significa que **el dato sobrevive y se recupera** en el siguiente arranque
de la app/servicio — **no** que Android reactive BLE automáticamente al
encender el dispositivo. Auto-arranque tras boot (`BOOT_COMPLETED`,
excepciones de optimización de batería, reinicio del foreground service)
es un problema aparte, fuera del alcance de esta ADR.

## Consequences
- (+) Un DISTRESS sobrevive process death, cierre de app y reinicio.
- (+) Deduplicación consistente entre nodos y con el futuro backend
  (`bejuco-platform`), misma estrategia de `message_id`.
- (+) `mesh/` permanece agnóstico de lógica de negocio, preservando la
  separación que el proyecto ya definió como no negociable.
- (-) Cada paquete válido implica una escritura a disco antes de
  considerarse aceptado — impacto en batería/latencia a medir bajo carga.
- (-) Room introduce superficie propia que cubrir explícitamente:
  migraciones de esquema, cifrado/protección de datos sensibles (el
  envelope incluye `location`, dato sensible por diseño en un contexto
  de desastre — mismo espíritu que la advertencia de
  `docs/2-MAESTRO_DE_ARQUITECTURA.md §6` sobre no acumular rutas de
  personas sin razón operacional), y pruebas de la ruta completa
  persistencia → restauración → relay.
- (-) Auto-arranque del mesh tras reinicio del dispositivo queda como
  trabajo pendiente separado; esta ADR solo garantiza que el dato no se
  pierde, no que el nodo retoma la propagación sin intervención del
  usuario.
