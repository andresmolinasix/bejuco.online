# Historias de usuario y casos de uso — Bejuco

**Documento funcional para implementación de interfaz y comportamiento sobre Bejuco Protocol V1**

---

## 1. Objetivo

Este documento define los primeros casos de uso de Bejuco sobre la infraestructura ya establecida de:

- Bluetooth Low Energy;
- descubrimiento de nodos;
- sincronización;
- persistencia local;
- deduplicación;
- store-carry-forward;
- gateway cuando exista conectividad.

Los casos de uso descritos aquí **no requieren una red diferente por funcionalidad**.

La arquitectura base permanece igual.

Lo que cambia principalmente entre casos de uso es:

- la interfaz;
- el tipo de mensaje;
- el payload;
- la prioridad;
- la forma en que se presenta la información al usuario.

Conceptualmente:

```text
                Bejuco Protocol V1
                        │
              Store · Carry · Forward
                        │
                   BLE / Mesh
                        │
        ┌───────────────┴───────────────┐
        │                               │
        ▼                               ▼
 Caso de uso 1                    Caso de uso 2
 Personas                         Abastecimiento
```

---

## 2. Principio de diseño

La aplicación no debe exponer al usuario conceptos técnicos como:

- mesh;
- peer;
- relay;
- TTL;
- gossip;
- sincronización GCS;
- store-carry-forward.

La interfaz debe traducir estos estados técnicos a conceptos comprensibles.

Ejemplo:

```text
STORED
   ↓
"Solicitud guardada"

RELAYING
   ↓
"Compartiendo con dispositivos cercanos"

DELIVERED
   ↓
"Solicitud entregada"
```

El diseño debe transmitir:

- confianza;
- simplicidad;
- claridad;
- continuidad;
- resiliencia;
- operación incluso sin Internet.

La UI debe ser minimalista y evitar sobrecargar al usuario durante una emergencia.

---

## 3. Caso de uso 1 — Localización y asistencia de personas

### 3.1 Objetivo

Permitir que una persona dentro de una zona afectada pueda indicar su estado después de un evento sísmico.

La persona podrá declarar:

```text
NECESITO AYUDA
```

o:

```text
ESTOY BIEN
```

Los dispositivos de las personas que no necesitan asistencia pueden continuar funcionando automáticamente como nodos de transporte para los paquetes de otros usuarios.

---

## 4. Historia de usuario 1A — Persona que necesita ayuda

### Historia

> Como persona afectada por un evento sísmico, quiero registrar una solicitud de ayuda con mi ubicación y datos básicos para que Bejuco pueda conservarla y propagarla entre dispositivos cercanos hasta que encuentre un punto de salida con conectividad.

### 4.1 Entrada de interfaz

Cuando Bejuco se encuentre en modo emergencia, mostrar:

```text
┌─────────────────────────────────┐
│             BEJUCO              │
│                                 │
│ Se detectó un evento sísmico    │
│ cerca de tu ubicación.          │
│                                 │
│ ¿Cuál es tu situación?          │
│                                 │
│ ┌─────────────────────────────┐ │
│ │     Necesito ayuda          │ │
│ └─────────────────────────────┘ │
│                                 │
│ ┌─────────────────────────────┐ │
│ │       Estoy bien            │ │
│ └─────────────────────────────┘ │
│                                 │
│ Bejuco puede funcionar incluso  │
│ sin conexión a Internet.        │
└─────────────────────────────────┘
```

### 4.2 Formulario de solicitud

Si el usuario selecciona:

```text
Necesito ayuda
```

mostrar:

```text
┌─────────────────────────────────┐
│ Necesito ayuda                  │
│                                 │
│ Nombre                          │
│ [________________________]      │
│                                 │
│ Teléfono                        │
│ [________________________]      │
│                                 │
│ Contacto de emergencia          │
│ [________________________]      │
│                                 │
│ Ubicación                       │
│ ● Detectada automáticamente     │
│                                 │
│ [ Enviar solicitud de ayuda ]   │
└─────────────────────────────────┘
```

### 4.3 Información mínima

Para el MVP:

```text
Nombre
Teléfono
Contacto de emergencia
Latitud
Longitud
Precisión GPS
Timestamp
Event ID
```

Evitar formularios extensos.

### 4.4 Tipo de paquete

```text
DISTRESS
```

Ejemplo conceptual:

```json
{
  "version": 1,
  "messageId": "unique-id",
  "eventId": "earthquake-id",
  "type": "DISTRESS",
  "originId": "device-id",
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
  "payload": {
    "name": "",
    "phone": "",
    "emergencyContact": ""
  },
  "signature": "..."
}
```

### 4.5 Confirmación de interfaz

Después de generar el paquete no mostrar inmediatamente:

```text
Mensaje enviado
```

porque el mensaje puede encontrarse únicamente almacenado localmente.

Usar estados reales:

```text
Solicitud guardada
        ↓
Compartiendo con dispositivos cercanos
        ↓
Solicitud entregada
```

Ejemplo:

```text
┌─────────────────────────────────┐
│ ✓ Solicitud guardada            │
│                                 │
│ Bejuco está compartiendo tu     │
│ solicitud con dispositivos      │
│ cercanos.                       │
│                                 │
│ No necesitas Internet.          │
│                                 │
│ ● Red Bejuco activa             │
│                                 │
│ Última transmisión              │
│ hace 12 segundos                │
└─────────────────────────────────┘
```

---

## 5. Historia de usuario 1B — Persona que está bien

### Historia

> Como persona que no necesita asistencia, quiero indicar que estoy bien y permitir que mi dispositivo continúe participando en la red para transportar solicitudes de otras personas sin intervención adicional.

### 5.1 Interfaz

Si selecciona:

```text
Estoy bien
```

mostrar:

```text
┌─────────────────────────────────┐
│ ✓ Estás marcado como seguro     │
│                                 │
│ Bejuco seguirá funcionando      │
│ para ayudar a transportar       │
│ solicitudes de otras personas.  │
│                                 │
│ ● Red Bejuco activa             │
└─────────────────────────────────┘
```

### 5.2 Separación entre estado y rol

La implementación debe diferenciar:

```text
ESTADO DE LA PERSONA
```

de:

```text
ROL DEL DISPOSITIVO
```

Ejemplo:

```text
Persona:
SAFE

Dispositivo:
RELAY
```

Una persona que está bien puede transportar:

```text
DISTRESS #001
DISTRESS #002
DISTRESS #003
```

sin conocer a sus emisores.

### 5.3 Comportamiento automático

Después de declarar:

```text
SAFE
```

la aplicación puede continuar:

```text
scan
 ↓
discover peer
 ↓
sync
 ↓
store
 ↓
carry
 ↓
forward
```

sin requerir acciones adicionales.

---

## 6. Caso de uso 2 — Solicitudes de suministros

### 6.1 Objetivo

Permitir que comunidades, puntos afectados o centros de atención sin Internet puedan comunicar necesidades de abastecimiento utilizando exactamente la misma infraestructura Bejuco.

Este caso de uso **no crea una nueva red**.

Reutiliza:

```text
BLE
sync
storage
deduplication
store-carry-forward
gateway
```

y cambia principalmente:

```text
message type
payload
interface
```

---

## 7. Historia de usuario 2A — Punto afectado solicita suministros

### Historia

> Como responsable de una comunidad o punto afectado, quiero registrar los suministros que necesitamos para que la solicitud pueda propagarse por Bejuco incluso cuando no exista conectividad a Internet.

### 7.1 Interfaz

```text
┌─────────────────────────────────┐
│ Solicitar suministros           │
│                                 │
│ ¿Qué necesitan?                 │
│                                 │
│ [ ] Agua                        │
│ [ ] Alimentos                   │
│ [ ] Medicamentos                │
│ [ ] Materiales                  │
│ [ ] Otro                        │
│                                 │
│ Cantidad / descripción          │
│ [________________________]      │
│ [________________________]      │
│                                 │
│ Ubicación                       │
│ ● Detectada                     │
│                                 │
│ [ Enviar solicitud ]            │
└─────────────────────────────────┘
```

### 7.2 Tipo de paquete

```text
SUPPLY_REQUEST
```

Ejemplo:

```json
{
  "version": 1,
  "messageId": "unique-id",
  "eventId": "earthquake-id",
  "type": "SUPPLY_REQUEST",
  "originId": "device-id",
  "createdAt": 0,
  "expiresAt": 0,
  "location": {
    "lat": 0.0,
    "lon": 0.0
  },
  "priority": "NORMAL",
  "hopCount": 0,
  "hopLimit": 20,
  "payload": {
    "category": "WATER",
    "quantity": 50,
    "unit": "LITERS",
    "description": "Agua potable"
  },
  "signature": "..."
}
```

---

## 8. Historia de usuario 2B — Centro de acopio recibe solicitudes

### Historia

> Como operador de un centro de acopio, quiero recibir y organizar las solicitudes que llegan por Bejuco para poder identificar qué recursos necesita cada zona afectada.

### 8.1 Interfaz operacional

```text
┌────────────────────────────────────────────┐
│ BEJUCO · Centro de acopio                  │
│                                            │
│ Solicitudes recibidas                  12  │
│                                            │
│ ● Agua                    50 L             │
│   San José del Palmar                     │
│   recibida hace 4 min                      │
│                                            │
│ ● Medicamentos            Prioridad alta   │
│   Nóvita                                   │
│   recibida hace 11 min                     │
│                                            │
│ ● Alimentos               30 personas      │
│   Tadó                                     │
│   recibida hace 18 min                     │
└────────────────────────────────────────────┘
```

### 8.2 Rol del centro de acopio

Conceptualmente:

```text
COORDINATOR
+
GATEWAY
```

Esto representa una función de aplicación.

No implica utilizar otro protocolo BLE.

---

## 9. Arquitectura compartida entre casos de uso

Los dos casos deben apoyarse sobre la misma infraestructura.

```text
                    BejucoEnvelope
                          │
                          ▼
                    Protocol V1
                          │
                          ▼
                  Persistent Store
                          │
                          ▼
                    Sync / Gossip
                          │
                          ▼
                       Relay
                          │
                          ▼
                 Bluetooth Low Energy
```

Por encima:

```text
                 Bejuco Protocol V1
                         │
          ┌──────────────┴──────────────┐
          │                             │
          ▼                             ▼
       DISTRESS                   SUPPLY_REQUEST
          │                             │
    UI personas                   UI suministros
```

---

## 10. Regla para nuevas funcionalidades

Agregar una nueva funcionalidad no debe implicar modificar innecesariamente la capa BLE.

Ejemplos futuros:

```text
MEDICAL_REQUEST
SHELTER_STATUS
SUPPLY_AVAILABLE
SAFE
ACK
```

La implementación esperada debe ser principalmente:

```text
nuevo MessageType
       +
nuevo Payload
       +
nueva Interface
```

y no:

```text
nuevo sistema de transporte
```

---

## 11. Contrato funcional con diseño

El diseño visual debe aplicarse especialmente en:

### Caso de uso 1

- selección de estado;
- formulario de emergencia;
- feedback de persistencia;
- estado de propagación;
- estado de entrega;
- modo SAFE;
- indicador de red activa.

### Caso de uso 2

- formulario de solicitud;
- selección de categorías;
- cantidad y unidades;
- confirmación de solicitud;
- bandeja de solicitudes recibidas;
- estados;
- prioridad;
- vista del centro de acopio.

---

## 12. Lenguaje visual esperado

La interfaz debe mantener el lenguaje gráfico definido para Bejuco:

- minimalista;
- información esencial;
- gran legibilidad;
- pocos elementos por pantalla;
- estados claros;
- microcopy breve;
- jerarquía tipográfica fuerte;
- bordes sutiles;
- colores funcionales;
- espacio negativo amplio.

No utilizar decoraciones que dificulten la operación durante una emergencia.

---

## 13. Semántica de color

Los colores deben tener significado.

```text
Neutral
→ interfaz general

Verde
→ conectado / seguro / activo

Ámbar
→ pendiente / propagando / atención

Rojo
→ DISTRESS / crítico

Gris
→ offline / desconocido / inactivo
```

El rojo no debe utilizarse como color decorativo principal de toda la aplicación.

Debe conservarse para información verdaderamente crítica.

---

## 14. Estados comunes de interfaz

Definir un componente visual reutilizable de estado.

Estados iniciales:

```text
STORED
RELAYING
DELIVERED
PENDING
EXPIRED
FAILED
```

Presentación para usuario:

```text
STORED
→ Solicitud guardada

RELAYING
→ Compartiendo con dispositivos cercanos

DELIVERED
→ Solicitud entregada

PENDING
→ Pendiente

EXPIRED
→ Solicitud expirada

FAILED
→ No fue posible procesar la solicitud
```

---

## 15. Principio final

El protocolo y la infraestructura deben permanecer desacoplados de la interfaz.

```text
                    Bejuco Core
                        │
       ┌────────────────┼────────────────┐
       │                │                │
       ▼                ▼                ▼
   Personas        Suministros       Futuro caso
       │                │                │
       ▼                ▼                ▼
      UI               UI               UI
```

El objetivo de diseño no es mostrar cómo funciona internamente la malla.

El objetivo es que una persona pueda utilizar Bejuco correctamente sin necesitar entenderla.

> **Una infraestructura compartida. Diferentes casos de uso. Interfaces específicas para cada necesidad.**
