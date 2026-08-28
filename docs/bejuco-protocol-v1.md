# Bejuco Protocol v1 — implementación iOS

## Envelope

La representación canónica es JSON UTF-8 con claves ordenadas:

```json
{
  "createdAt": 0,
  "eventId": "earthquake-id",
  "expiresAt": 0,
  "hopCount": 0,
  "hopLimit": 20,
  "location": { "accuracy": 12, "lat": 5.69, "lon": -76.66 },
  "messageId": "uuid",
  "originId": "pseudonymous-node-id",
  "originPublicKey": "base64-p256-public-key",
  "payload": {},
  "priority": "CRITICAL",
  "signature": "base64-der-ecdsa-signature",
  "type": "DISTRESS",
  "version": 1
}
```

`createdAt` y `expiresAt` son Unix milliseconds. `messageId` identifica el paquete globalmente y es la clave de deduplicación. `hopCount` aumenta al ser recibido por un relay y el paquete deja de propagarse cuando alcanza `hopLimit` o expira.

## Integridad

- Cada dispositivo genera una clave P-256 y conserva la privada en Keychain.
- `originId` es el prefijo hexadecimal de SHA-256 de la clave pública.
- La firma es ECDSA sobre DER y se codifica en Base64.
- La firma cubre el envelope sin `signature` y con `hopCount = 0`; de ese modo un relay puede incrementar el contador sin alterar la autenticidad del origen.
- Un paquete con firma presente e inválida se rechaza. Un paquete sin firma se conserva para compatibilidad de desarrollo, pero no debe considerarse autenticado.

## Sync mesh

El servicio BLE anuncia un servicio Bejuco con dos características:

| UUID | Uso |
|---|---|
| `A7E10000-7B5A-4D3E-9A11-0B7A00000001` | Servicio mesh |
| `A7E10001-7B5A-4D3E-9A11-0B7A00000001` | Inventario, requests y control |
| `A7E10002-7B5A-4D3E-9A11-0B7A00000001` | Chunks de paquetes |

Al conectarse, ambos nodos envían un inventario paginado. Cada nodo solicita los `messageId` que le faltan y entrega los paquetes que el peer no tiene. El envelope completo se transporta en Base64 dividido en frames JSON pequeños para respetar el MTU de BLE.

## Tipos de payload

- `DISTRESS`: `name`, `phone`, `contactName`, `notes`.
- `SAFE`: `name`, `contactName`, `notes`.
- `SUPPLY_REQUEST`: `item`, `quantity`, `notes`.

La ubicación es opcional para permitir estados `SAFE` cuando el usuario todavía no concedió ubicación; el flujo de SOS la exige antes de crear el paquete.

