# Revisión BitChat y compatibilidad Android/iOS

## Fuentes comparadas

- bejuco.online, rama main: fork Android de BitChat con una capa de
  emergencia Bejuco. La documentación del propio proyecto identifica a
  mesh/ como transporte y a emergency/ como el adaptador que conoce
  BejucoEnvelope.
- BitChat upstream: [permissionlesstech/bitchat](https://github.com/permissionlesstech/bitchat).
  La revisión iOS se hizo sobre el commit 9b84b36.
- El Android de Bejuco documenta como base de BitChat Android el commit
  4f828b5 del repositorio upstream Android.

## Contrato que usa Bejuco

La alerta no inventa un transporte BLE separado. Se serializa como JSON UTF-8
firmado con Ed25519 y se envía como payload opaco de un paquete BitChat:

- Servicio GATT: F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5C.
- Characteristic: A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D.
- 0x30: BEJUCO_ENVELOPE.
- 0x20: FRAGMENT.
- Cabecera binaria big-endian BitChat v1/v2.
- Deflate raw cuando la compresión reduce el tamaño.
- Paquetes Bejuco y fragmentos sin padding; el padding se reserva para
  paquetes Noise.
- Umbral BLE de 512 bytes, tamaño máximo conservador de fragmento de 469
  bytes y límites de reensamblación de 64 conjuntos activos, 1 MiB por
  conjunto, 4 MiB globales y 30 segundos de expiración.

Para `0x30`, la firma obligatoria es la del envelope interno. Android deja el
paquete BitChat externo fuera de la validación de firmas asociada a mensajes
de chat, por lo que iOS puede enviarlo sin firma externa y conservar la
verificación Ed25519 del payload Bejuco.

El envelope interno mantiene el orden de campos Gson de Android, omite
opcionales nulos, usa claves y firmas hexadecimales minúsculas, y deriva
originId de los primeros ocho bytes de SHA-256(originPublicKeyHex UTF-8).
El hopCount se excluye de la preimagen firmada, por lo que un relay puede
actualizarlo sin romper la firma de origen.

## Cambios aplicados en iOS

MeshService anuncia y busca el servicio BitChat, usa la misma characteristic,
fragmenta según la capacidad negociada de cada enlace, reensambla por
senderID + fragmentID, aplica los mismos límites de memoria y releva el
paquete opaco decrementando el TTL externo. El envelope se valida después en
la capa Bejuco y se persiste localmente.

El transporte nativo iOS anterior se conserva como fallback de pruebas iOS↔iOS;
no participa en el camino Android↔iOS cuando existe la characteristic BitChat.

## Alcance actual

La compatibilidad común cubre los tipos que Android declara hoy:
DISTRESS y SAFE. Los tipos adicionales del modelo iOS siguen fuera del
contrato Android hasta que su enum y repositorio se amplíen.

Esto no convierte todavía a Bejuco iOS en el cliente completo de BitChat:
no implementa la conversación genérica, sesiones Noise, anuncios de identidad
ni Nostr del upstream. Es una integración del transporte BitChat para el flujo
de alertas Bejuco, que es la interfaz que la rama Android expone actualmente.
