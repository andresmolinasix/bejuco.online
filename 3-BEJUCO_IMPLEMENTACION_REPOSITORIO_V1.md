# Bejuco — Guía de implementación inicial del repositorio

**Documento para equipo de desarrollo**  
**Alcance:** aplicación móvil y organización inicial de repositorios.  
**Fuera de alcance de este documento:** infraestructura GCP, despliegue backend y operación cloud.

---

## 1. Objetivo técnico

Bejuco es una red de comunicación de emergencia tolerante a interrupciones. El objetivo del MVP es permitir que un paquete crítico generado en un dispositivo Android pueda:

1. persistir localmente;
2. propagarse entre dispositivos cercanos mediante Bluetooth Low Energy (BLE);
3. sobrevivir a desconexiones, Bluetooth OFF/ON, cierre de la app y reinicio del dispositivo;
4. continuar propagándose mediante un modelo **store-carry-forward**;
5. quedar preparado para ser entregado posteriormente a un gateway con acceso a Internet.

La primera versión **no debe plantearse como una aplicación de chat**. El elemento central del sistema es un **paquete de emergencia persistente y transportable**, no una conversación entre usuarios.

---

# 2. Decisión de plataforma: Android nativo primero

## 2.1 Tecnología seleccionada

La primera implementación móvil debe desarrollarse en:

- **Kotlin**
- **Android nativo**
- **Jetpack Compose** para UI
- **Room / SQLite** para persistencia local
- APIs nativas de **Bluetooth Low Energy**
- Coroutines / Flow para concurrencia y estados reactivos
- Foreground Service cuando sea necesario mantener operaciones BLE bajo las restricciones de Android

No se utilizará React Native para el MVP.

## 2.2 Motivo de la decisión

El problema principal de Bejuco no está en la interfaz gráfica sino en el comportamiento del dispositivo frente a:

- BLE scanning;
- BLE advertising;
- descubrimiento de peers;
- conexiones GATT;
- reconexión;
- ejecución en background;
- foreground services;
- Bluetooth OFF/ON;
- pérdida y recuperación de conectividad;
- persistencia;
- process death;
- reinicio del dispositivo;
- consumo energético;
- intercambio y deduplicación de paquetes.

Estas funcionalidades dependen fuertemente de APIs y reglas específicas del sistema operativo.

React Native no elimina esta complejidad. Para soportar correctamente BLE en Android seguiría siendo necesario implementar módulos nativos en Kotlin, y posteriormente módulos independientes en Swift para iOS.

Por tanto, para el MVP se prioriza la menor cantidad posible de capas:

```text
Bejuco Android
      │
      ├── Jetpack Compose
      ├── Kotlin
      ├── Android BLE APIs
      ├── Room / SQLite
      └── Foreground Services
```

## 2.3 Estrategia multiplataforma

El desarrollo se divide en fases:

```text
FASE 1
────────────────────
Android
Kotlin
Jetpack Compose
Room / SQLite
Android BLE

FASE 2
────────────────────
iOS
Swift
SwiftUI
Core Bluetooth
Persistencia local iOS
```

La interoperabilidad futura entre Android, iOS y otros nodos no dependerá de compartir código de aplicación, sino de implementar una especificación común:

```text
Bejuco Protocol v1
```

La especificación debe definir el formato de paquetes, identificadores, serialización, firma, TTL, deduplicación y reglas de sincronización de forma independiente del lenguaje.

---

# 3. Repositorio Android

## 3.1 Repositorio principal

Crear:

```text
bejuco-android
```

Este repositorio será la implementación Android del protocolo y del comportamiento offline.

Debe partir de `permissionlesstech/bitchat-android` como referencia/base técnica para la capa BLE y de sincronización, pero Bejuco debe evolucionar hacia una arquitectura propia orientada a información de emergencia persistente.

## 3.2 Upstream

El repositorio original de BitChat debe mantenerse como `upstream`.

Configuración esperada:

```text
origin
  └── repositorio Bejuco

upstream
  └── permissionlesstech/bitchat-android
```

Ejemplo:

```bash
git remote -v
```

Resultado conceptual:

```text
origin    git@github.com:<org>/bejuco-android.git
upstream  https://github.com/permissionlesstech/bitchat-android.git
```

El objetivo de conservar `upstream` es poder revisar mejoras futuras relacionadas con:

- BLE;
- compatibilidad Android;
- scanning;
- advertising;
- fragmentación;
- reconexión;
- foreground services;
- consumo de batería;
- sincronización.

No se recomienda hacer merges automáticos frecuentes desde `upstream/main`.

La preferencia debe ser:

1. revisar el cambio upstream;
2. identificar el commit relevante;
3. evaluar impacto;
4. aplicar selectivamente mediante `cherry-pick` o implementación equivalente.

A medida que Bejuco evolucione, su comportamiento diferirá progresivamente del de BitChat.

---

## 3.3 Congelar la base inicial

Antes de modificar significativamente el código, registrar exactamente qué commit de BitChat fue usado como punto de partida.

Crear un tag:

```bash
git tag bitchat-base-v1
git push origin bitchat-base-v1
```

Además crear:

```text
docs/upstream.md
```

Contenido mínimo:

```md
# Upstream

Repository:
https://github.com/permissionlesstech/bitchat-android

Base commit:
<COMMIT_SHA>

Date:
<YYYY-MM-DD>

Purpose:
Initial BLE and mesh implementation used as the technical baseline for Bejuco.
```

Esto permite reproducibilidad y trazabilidad técnica.

---

# 4. Estructura propuesta para `bejuco-android`

No se debe realizar un refactor masivo de BitChat al inicio.

La migración debe ser incremental.

Estructura objetivo:

```text
bejuco-android/
│
├── app/
│   └── src/main/java/...
│
├── mesh/
│   ├── discovery/
│   ├── transport/
│   ├── peer/
│   └── relay/
│
├── sync/
│   ├── inventory/
│   ├── gossip/
│   └── deduplication/
│
├── protocol/
│   ├── packet/
│   ├── codec/
│   └── signature/
│
├── emergency/
│   ├── EmergencyMode
│   ├── DistressMessage
│   └── SafetyStatus
│
├── storage/
│   ├── MessageEntity
│   ├── MessageDao
│   └── BejucoDatabase
│
├── gateway/
│   ├── InternetDetector
│   ├── UploadQueue
│   └── GatewayClient
│
├── security/
│
├── ui/
│
└── docs/
```

> Nota: la estructura física exacta puede adaptarse al sistema de módulos Gradle existente. Lo importante es preservar la separación de responsabilidades.

---

# 5. Responsabilidad de cada módulo

## `mesh/`

Responsable exclusivamente de comunicación entre dispositivos.

Debe encargarse de:

- descubrimiento de nodos;
- scanning BLE;
- advertising;
- conexiones;
- transporte de bytes;
- fragmentación y reensamblado;
- relay;
- control de peers.

No debe contener lógica de negocio de emergencia.

El módulo `mesh` no debe interpretar que un paquete significa "SOS", "SAFE" o "SUPPLY_REQUEST".

---

## `sync/`

Responsable de determinar qué información posee cada nodo y cuál necesita intercambiar.

Debe implementar:

- identificación de paquetes conocidos;
- inventario local;
- deduplicación;
- sincronización al detectar nuevos peers;
- resincronización tras reconexión;
- intercambio únicamente de información faltante.

El sistema debe soportar **eventual consistency** entre nodos.

Caso mínimo:

```text
Nodo A posee:
M1 M2 M3

Nodo B posee:
M1 M3 M4

Después de sincronizar:

A:
M1 M2 M3 M4

B:
M1 M2 M3 M4
```

La sincronización no debe depender de que el emisor original siga conectado.

---

## `protocol/`

Define los paquetes Bejuco.

Esta capa debe ser independiente de UI, BLE y base de datos.

Responsabilidades:

- modelo `BejucoEnvelope`;
- tipos de mensajes;
- codificación;
- decodificación;
- `messageId`;
- versión del protocolo;
- hash;
- firma;
- TTL;
- hop count;
- expiración.

Ejemplo conceptual:

```json
{
  "version": 1,
  "messageId": "unique-id",
  "eventId": "earthquake-id",
  "type": "DISTRESS",
  "originId": "pseudonymous-device-id",
  "createdAt": 0,
  "expiresAt": 0,
  "location": {
    "lat": 0.0,
    "lon": 0.0,
    "accuracy": 0
  },
  "priority": "SOS",
  "hopCount": 0,
  "hopLimit": 20,
  "payload": {},
  "signature": "..."
}
```

El formato definitivo debe documentarse antes de declarar `Bejuco Protocol v1` estable.

---

## `emergency/`

Contiene la lógica de negocio relacionada con emergencias.

Ejemplos iniciales:

```text
DISTRESS
SAFE
```

Posteriormente pueden incorporarse:

```text
SUPPLY_REQUEST
SUPPLY_AVAILABLE
MEDICAL_REQUEST
SHELTER_STATUS
ACK
```

Estos tipos no deben modificar el funcionamiento fundamental del transporte BLE.

---

## `storage/`

La persistencia es obligatoria para el MVP.

Un paquete recibido no puede vivir exclusivamente en memoria.

Se utilizará Room/SQLite.

Tabla conceptual:

```text
messages
─────────────────────────────
message_id
event_id
type
origin_id
created_at
expires_at
payload
signature
hop_count
received_at
upload_state
```

Propiedad crítica:

```text
mensaje recibido
      │
      ▼
persistencia local
      │
      ├── Bluetooth OFF
      ├── app cerrada
      ├── proceso eliminado
      └── teléfono reiniciado
      │
      ▼
mensaje sigue disponible
```

El sistema debe tratar esta propiedad como criterio de aceptación, no como mejora futura.

---

## `gateway/`

En Android, esta capa detectará cuándo existe conectividad externa y expondrá los paquetes pendientes para su posterior entrega al backend.

Aunque la infraestructura cloud queda fuera de este documento, el cliente debe desacoplar el transporte mesh del transporte Internet.

Conceptualmente:

```text
BLE / mesh
      │
      ▼
local database
      │
      ▼
gateway queue
      │
      ▼
Internet available
```

No debe existir dependencia directa:

```text
BLE packet
   ↓
HTTP request inmediato
```

porque precisamente el sistema debe funcionar cuando HTTP no está disponible.

---

## `security/`

Responsable de:

- identidad pseudónima del dispositivo;
- generación y almacenamiento de claves;
- firma de paquetes;
- validación de firmas;
- hash;
- protección contra alteraciones;
- prevención básica de replay.

Para el MVP no es obligatorio implementar mensajería privada cifrada, pero sí debe evitarse diseñar un protocolo que no permita verificar integridad y autenticidad.

---

# 6. Segundo repositorio: `bejuco-platform`

Crear un segundo repositorio:

```text
bejuco-platform
```

Su objetivo es mantener especificaciones, backend y componentes compartidos de plataforma sin mezclar el ciclo de vida del proyecto Android.

Aunque la infraestructura GCP será gestionada internamente y no forma parte de este documento, el repositorio debe reservar una organización clara para los componentes de plataforma.

Estructura recomendada:

```text
bejuco-platform/
│
├── backend/
│
├── dashboard/
│
├── database/
│   └── migrations/
│
├── protocol/
│   ├── bejuco-v1.md
│   ├── packet-types.md
│   ├── examples/
│   └── test-vectors/
│
└── docs/
    ├── architecture/
    ├── threat-model/
    └── adr/
```

La carpeta más importante inicialmente es:

```text
protocol/
```

---

# 7. `Bejuco Protocol v1` como contrato entre implementaciones

La especificación del protocolo no debe existir únicamente como clases Kotlin.

Debe existir como documento independiente.

Archivo:

```text
bejuco-platform/protocol/bejuco-v1.md
```

Debe especificar como mínimo:

```text
protocolVersion
messageId
eventId
messageType
originId
createdAt
expiresAt
location
priority
hopCount
hopLimit
payload
signature
```

También debe definir:

- representación binaria o serialización;
- endianness cuando aplique;
- algoritmo de hash;
- generación de `messageId`;
- algoritmo de firma;
- reglas de TTL;
- reglas de expiración;
- comportamiento de relay;
- reglas de deduplicación;
- reglas de ACK;
- compatibilidad entre versiones.

El objetivo es que puedan existir implementaciones diferentes:

```text
               Bejuco Protocol v1
                       │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
     Android          iOS           ESP32
      Kotlin          Swift           C/C++
```

sin que ninguna sea considerada la definición canónica del protocolo.

---

# 8. Test vectors

Desde el inicio crear:

```text
bejuco-platform/protocol/test-vectors/
```

Ejemplo:

```text
distress-message-001.json
distress-message-001.bin
distress-message-001.sha256
```

Cada implementación debe ser capaz de tomar los mismos datos y producir exactamente la misma representación esperada.

Esto será especialmente importante cuando se implemente iOS o ESP32.

---

# 9. ADR — Architecture Decision Records

Crear:

```text
docs/adr/
```

Para las decisiones relevantes.

Ejemplo:

```text
0001-native-android-first.md
0002-bitchat-as-upstream.md
0003-persistent-store-carry-forward.md
0004-protocol-independent-from-platform.md
```

Formato mínimo:

```md
# ADR-0001: Android nativo primero

## Status
Accepted

## Context
...

## Decision
...

## Consequences
...
```

El objetivo es evitar que dentro de varios meses se repitan discusiones ya resueltas sin conocer el contexto original.

---

# 10. Estrategia de implementación sobre BitChat

No se debe intentar transformar todo BitChat en Bejuco en una sola operación.

Secuencia recomendada:

```text
BitChat Android existente
        │
        ▼
mantener BLE funcional
        │
        ▼
introducir BejucoEnvelope
        │
        ▼
introducir persistencia Room
        │
        ▼
modificar sincronización
        │
        ▼
store-carry-forward persistente
        │
        ▼
eliminar progresivamente funciones de chat
```

La prioridad es conservar una red BLE funcional mientras se reemplaza el modelo de datos.

---

# 11. Componentes de BitChat que deben revisarse primero

Tomar como referencia:

```text
BluetoothMeshService
UnifiedMeshService
GossipSyncManager
StoreForwardManager
PeerManager
MessageHandler
MeshForegroundService
```

No asumir que su comportamiento actual es correcto para Bejuco.

Especialmente:

## `GossipSyncManager`

Debe revisarse para que los mensajes de emergencia persistan independientemente de que el peer originador siga visible.

Un SOS no debe desaparecer simplemente porque:

```text
peer originador → stale/offline
```

Debe ocurrir:

```text
peer originador → stale/offline
        │
        ▼
mensaje permanece almacenado
        │
        ▼
continúa propagándose
```

## `StoreForwardManager`

El modelo existente de BitChat está orientado a mensajes de chat y entrega a peers.

Bejuco debe evolucionar hacia:

```text
store
  ↓
carry
  ↓
discover peer
  ↓
compare inventory
  ↓
forward missing packets
```

La unidad de almacenamiento es el paquete, no la conversación.

---

# 12. Criterio de aceptación técnico inicial

El primer milestone debe demostrar:

```text
A genera M1
    │
    ▼
M1 se guarda en Room
    │
    ▼
A encuentra B
    │
    ▼
B recibe M1
    │
    ▼
B guarda M1
```

Luego:

```text
Bluetooth B OFF
        │
        ▼
Bluetooth B ON
        │
        ▼
B encuentra C
        │
        ▼
C recibe M1
```

Finalmente:

```text
A puede estar apagado
B puede no tener Internet
A y C pueden no haberse encontrado nunca
```

y aun así:

```text
C conserva M1
```

Este comportamiento es el núcleo del MVP.

---

# 13. Pruebas obligatorias antes de desarrollar funcionalidades adicionales

Antes de agregar casos como suministros, centros de acopio o ESP32, deben pasar las siguientes pruebas:

```text
[ ] A → B transferencia BLE

[ ] mensaje persistente en A

[ ] mensaje persistente en B

[ ] Bluetooth OFF/ON conserva información

[ ] cierre de app conserva información

[ ] process death conserva información

[ ] reinicio de dispositivo conserva información

[ ] B → C sin presencia de A

[ ] deduplicación de M1

[ ] múltiples copias no crean múltiples mensajes

[ ] sincronización recupera mensajes faltantes

[ ] mensajes expirados dejan de propagarse según protocolo

[ ] hopCount/hopLimit funcionan según protocolo
```

---

# 14. Fuera del alcance del MVP inicial

No implementar todavía:

```text
chat
mensajes privados
Nostr
blockchain
ESP32
fotografías
audio
iOS
sistemas de suministros
centros de acopio
clasificación automática de afectados
```

Estos componentes pueden añadirse después de demostrar que el transporte store-carry-forward es confiable.

---

# 15. Resultado esperado del primer ciclo de desarrollo

Al finalizar esta fase debe existir:

```text
bejuco-android
│
├── BLE funcional
├── BejucoEnvelope
├── Room
├── persistencia
├── deduplicación
├── sincronización
└── store-carry-forward
```

y:

```text
bejuco-platform
│
├── protocol/
│   ├── bejuco-v1.md
│   ├── packet-types.md
│   ├── examples/
│   └── test-vectors/
│
└── docs/
    ├── architecture/
    ├── threat-model/
    └── adr/
```

El éxito de esta fase no se mide por cantidad de pantallas o funcionalidades.

Se mide por demostrar:

> **Un paquete originado por un dispositivo puede persistir, sobrevivir a interrupciones y desplazarse oportunísticamente entre nodos Android mediante BLE, aunque el dispositivo originador desaparezca de la red.**

---

## Decisiones congeladas para V1

| Área | Decisión |
|---|---|
| Plataforma inicial | Android nativo |
| Lenguaje | Kotlin |
| UI | Jetpack Compose |
| Transporte local | Bluetooth Low Energy |
| Persistencia | Room / SQLite |
| Arquitectura offline | Store-carry-forward |
| Referencia BLE | BitChat Android |
| Interoperabilidad | Bejuco Protocol v1 |
| Repositorio móvil | `bejuco-android` |
| Repositorio plataforma | `bejuco-platform` |
| iOS | Posterior al MVP |
| React Native | No usar en V1 |

