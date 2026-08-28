# Bejuco Protocol v1 — implementación iOS/Android

## Envelope

El envelope se transporta como JSON UTF-8 con la forma que actualmente usa
Android (`protocol/BejucoEnvelope.kt`). Para que la firma sea verificable entre
plataformas, iOS conserva el orden de campos de Gson y omite los opcionales
nulos:

```json
{"version":1,"messageId":"uuid","eventId":"earthquake-id","type":"DISTRESS","originId":"0011223344556677","originPublicKey":"ed25519-public-key-hex","createdAt":0,"expiresAt":0,"location":{"lat":5.69,"lon":-76.66,"accuracy":12.0},"priority":"SOS","hopCount":0,"hopLimit":20,"payload":{"name":"Ana"},"signature":"ed25519-signature-hex"}
```

`eventId`, `location`, `originPublicKey` y `signature` pueden omitirse cuando
son nulos. `createdAt` y `expiresAt` son Unix milliseconds. `messageId`
identifica el paquete globalmente y `hopCount` aumenta al ser recibido por un
relay; la firma se calcula con `hopCount = 0` para que el relay pueda cambiar
ese contador sin invalidar el origen.

## Integridad e identidad

- Cada dispositivo genera una clave Ed25519 y conserva la privada en Keychain (iOS) o almacenamiento cifrado (Android).
- `originPublicKey` es la clave pública Ed25519 de 32 bytes en hexadecimal minúsculo.
- `originId` es el primer bloque de 8 bytes de `SHA-256(originPublicKeyHex UTF-8)`, codificado como 16 caracteres hexadecimales.
- `signature` es la firma Ed25519 de 64 bytes en hexadecimal minúsculo.
- La preimagen firmada contiene todos los campos salvo `signature` y normaliza `hopCount` a cero.

## Transporte BitChat BLE

Android y la capa compatible de iOS usan un único servicio GATT y un único
characteristic:

| UUID | Uso |
|---|---|
| `F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5C` | Servicio BitChat mesh |
| `A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D` | Escritura y notificación de paquetes binarios |

El paquete binario v1 usa big-endian y tiene este orden:

```text
version (1) | type (1) | ttl (1) | timestamp UInt64 (8) |
flags (1) | payloadLength UInt16 (2) | senderID (8) |
recipientID (8, si flags.hasRecipient) | payload | signature (64, si existe)
```

El tipo `0x30` (`BEJUCO_ENVELOPE`) lleva el JSON del envelope como payload
opaco. El tipo `0x20` (`FRAGMENT`) divide paquetes que superan el umbral de
512 bytes usando el encabezado compartido de 13 bytes: ID de fragmento (8),
índice (UInt16), total (UInt16) y tipo original (1). El compresor usa deflate
raw y la capa acepta también el formato zlib para compatibilidad.

La implementación iOS mantiene además el servicio nativo anterior:

| UUID | Uso |
|---|---|
| `A7E10000-7B5A-4D3E-9A11-0B7A00000001` | Servicio iOS legacy |
| `A7E10001-7B5A-4D3E-9A11-0B7A00000001` | Inventario y control |
| `A7E10002-7B5A-4D3E-9A11-0B7A00000001` | Transferencia de envelopes |

Esto permite seguir probando iOS↔iOS mientras se migra el store-and-forward
completo al protocolo común.

## Tipos y alcance Android actual

- `DISTRESS`: compatible entre Android e iOS.
- `SAFE`: compatible entre Android e iOS.
- `SUPPLY_REQUEST`, `SUPPLY_AVAILABLE`, `MEDICAL_REQUEST`, `SHELTER_STATUS` y `ACK`: disponibles en el modelo iOS, pero Android debe ampliar su enum antes de recibirlos por el transporte común.

La ubicación es opcional para `SAFE`; el flujo de SOS la exige antes de crear
el paquete.
