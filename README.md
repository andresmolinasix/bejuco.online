# Bejuco iOS

Implementación iOS nativa de Bejuco, una red de comunicación de emergencia tolerante a interrupciones.

## Estado de este primer corte

El proyecto ya está configurado como `Bejuco.xcodeproj` y compila con Xcode 26.6 / iOS 26.5 SDK. Incluye:

- SwiftUI con pantallas de inicio, emergencia, paquetes y ajustes.
- `BejucoEnvelope` v1 con timestamps Unix en milisegundos, TTL, `hopCount`/`hopLimit`, ubicación y payload.
- Firma Ed25519 con CryptoKit e identidad pseudónima conservada en Keychain, compatible con Android.
- Persistencia local JSON en Application Support con protección de archivos.
- Deduplicación por `messageId` y store-carry-forward.
- Core Bluetooth como central y periférico simultáneamente, con transporte BitChat-compatible para alertas Android↔iOS y un fallback nativo iOS para inventario/store-and-forward.
- Estados `DISTRESS`, `SAFE` y `SUPPLY_REQUEST`.
- Consulta del feed GeoJSON de terremotos de USGS.
- Cola de entrega HTTP `POST /v1/messages/batch` cuando vuelve Internet.
- BGProcessingTask para reintentar consulta USGS y entrega del gateway.
- Notificaciones locales de emergencia para `DISTRESS` recibidos por mesh y una pestaña dedicada `Alertas`.
- Pruebas unitarias de protocolo, firma, relay y deduplicación.

## Abrir en Xcode

```bash
open /Users/leonardo/Documents/hackahon-google-app-ios/Bejuco.xcodeproj
```

Selecciona el target `Bejuco`, un simulador o un iPhone conectado y configura tu Team de firma en Xcode. El bundle identifier inicial es `online.bejuco.ios`; cámbialo si tu cuenta necesita otro.

## Verificación reproducible

```bash
xcodebuild -project Bejuco.xcodeproj \
  -scheme Bejuco \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/bejuco-derived \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild test -project Bejuco.xcodeproj \
  -scheme Bejuco \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -derivedDataPath /tmp/bejuco-test-derived \
  CODE_SIGNING_ALLOWED=NO
```

## Prueba mesh con dos iPhones

El simulador sirve para UI, persistencia y protocolo, pero no reemplaza una prueba BLE entre teléfonos físicos. Para el criterio A → B → C:

1. Instala la app en tres iPhones con Bluetooth y permisos de Bluetooth/ubicación habilitados.
2. En A, solicita ubicación y crea un paquete `Necesito ayuda`.
3. Confirma que B lo recibe en `Paquetes` y que el contador de `hop` aumenta.
4. Apaga y enciende Bluetooth en B; deja A fuera de alcance.
5. Acerca C a B y confirma que C recibe el mismo `messageId`.
6. Configura el endpoint del gateway en C y conecta C a Internet.
7. Comprueba que el paquete pasa de `pendiente` a `entregado`.

Al recibir un `DISTRESS` válido, iOS lo muestra en la pestaña `Alertas` y
programa una notificación local con banner y sonido. El permiso se solicita al
primer arranque y se puede revisar en `Ajustes > Alertas de emergencia`.

La ejecución en segundo plano de iOS depende de las reglas de Core Bluetooth del sistema; `Info.plist` ya declara `bluetooth-central`, `bluetooth-peripheral` y `processing`, pero el comportamiento debe probarse en dispositivos reales y con batería/permiso reales.

## Prueba con Android

La interoperabilidad BLE directa está implementada para el contrato actual de Android: iOS anuncia y busca `F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5C`, usa el characteristic `A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D`, encapsula los envelopes como `BEJUCO_ENVELOPE (0x30)`, releva por TTL y soporta compresión, padding selectivo y fragmentación BitChat v1/v2. El detalle de la comparación con upstream está en [docs/upstream.md](/Users/leonardo/Documents/hackahon-google-app-ios/docs/upstream.md).

La prueba Android↔iOS requiere dos teléfonos físicos con Bluetooth y permisos habilitados. En el Android actual los tipos Bejuco aceptados por su enum son `DISTRESS` y `SAFE`; `SUPPLY_REQUEST` continúa disponible en el transporte nativo iOS hasta que Android amplíe su contrato. El simulador solo sirve para validar UI, persistencia y codec; no sustituye una prueba BLE real.

## Backend

El endpoint se configura en `Ajustes`. El valor inicial de desarrollo es
`https://bejuco-dev-ingest-api-w6gswgwgyq-uc.a.run.app/v1/messages/batch` y el
cliente envía el contrato `{"gatewayId":"…","messages":[…]}` definido por
`bejuco-platform`. La API de Cloud Run es pública y no requiere credenciales de
Cloud SQL en el teléfono. Si el backend no está disponible, los paquetes siguen
persistiendo localmente y quedan en estado `failed` para reintento.

## Protocolo

La forma del paquete y las reglas de relay están documentadas en [docs/bejuco-protocol-v1.md](/Users/leonardo/Documents/hackahon-google-app-ios/docs/bejuco-protocol-v1.md). La implementación evita que `hopCount` invalide la firma de origen: el contador se normaliza a cero en la representación firmada.
