# Bejuco iOS

Implementación iOS nativa de Bejuco, una red de comunicación de emergencia tolerante a interrupciones.

## Estado de este primer corte

El proyecto ya está configurado como `Bejuco.xcodeproj` y compila con Xcode 26.6 / iOS 26.5 SDK. Incluye:

- SwiftUI con pantallas de inicio, emergencia, paquetes y ajustes.
- `BejucoEnvelope` v1 con timestamps Unix en milisegundos, TTL, `hopCount`/`hopLimit`, ubicación y payload.
- Firma ECDSA P-256 con CryptoKit e identidad pseudónima conservada en Keychain.
- Persistencia local JSON en Application Support con protección de archivos.
- Deduplicación por `messageId` y store-carry-forward.
- Core Bluetooth como central y periférico simultáneamente, con inventario, solicitud de faltantes y transferencia por chunks GATT.
- Estados `DISTRESS`, `SAFE` y `SUPPLY_REQUEST`.
- Consulta del feed GeoJSON de terremotos de USGS.
- Cola de entrega HTTP `POST /v1/messages/batch` cuando vuelve Internet.
- BGProcessingTask para reintentar consulta USGS y entrega del gateway.
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

La ejecución en segundo plano de iOS depende de las reglas de Core Bluetooth del sistema; `Info.plist` ya declara `bluetooth-central`, `bluetooth-peripheral` y `processing`, pero el comportamiento debe probarse en dispositivos reales y con batería/permiso reales.

## Prueba con Android

La app iOS de este corte se puede instalar y probar de forma independiente en un iPhone físico. La interoperabilidad BLE directa con la app Android del repositorio `bejuco.online` todavía requiere el adaptador de transporte BitChat: Android anuncia el servicio `F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5C`, usa un characteristic único y encapsula los paquetes como `BEJUCO_ENVELOPE (0x30)`, mientras que este corte iOS usa el servicio `A7E10000-7B5A-4D3E-9A11-0B7A00000001` con frames de control y transferencia propios.

En consecuencia, antes del adaptador se pueden validar UI, ubicación, persistencia, firma, gateway y mesh iOS↔iOS; no se debe declarar todavía una prueba BLE Android↔iOS como exitosa.

## Backend

El endpoint se configura en `Ajustes`. El valor inicial es `https://bejuco.online/v1/messages/batch` como placeholder configurable; si el backend todavía no está desplegado, los paquetes siguen persistiendo localmente y quedan en estado `failed` para reintento.

## Protocolo

La forma del paquete y las reglas de relay están documentadas en [docs/bejuco-protocol-v1.md](/Users/leonardo/Documents/hackahon-google-app-ios/docs/bejuco-protocol-v1.md). La implementación evita que `hopCount` invalide la firma de origen: el contador se normaliza a cero en la representación firmada.
