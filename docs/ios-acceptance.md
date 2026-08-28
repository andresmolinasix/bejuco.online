# Criterios de aceptación iOS

## Automatizados

- [x] El proyecto abre como `Bejuco.xcodeproj`.
- [x] La app compila para iOS Simulator.
- [x] El envelope se serializa y deserializa con campos estables.
- [x] Una firma válida se verifica después de incrementar `hopCount`.
- [x] El almacén deduplica paquetes con el mismo `messageId`.
- [x] El envelope iOS usa Ed25519, hexadecimal y `originId` compatibles con Android.
- [x] El codec iOS implementa el paquete BitChat v1, compresión y fragmentación.

## Manuales en dispositivo físico

- [ ] A → B transfiere un paquete `DISTRESS` por BLE.
- [ ] El paquete persiste en A y B después de cerrar la app.
- [ ] Bluetooth OFF/ON no elimina el paquete.
- [ ] B → C funciona sin que A vuelva a estar presente.
- [ ] Copias múltiples del paquete producen un único registro.
- [ ] Un paquete vencido no se retransmite.
- [ ] `hopCount`/`hopLimit` detienen el relay.
- [ ] C entrega el lote al backend cuando vuelve Internet.

## Android ↔ iOS

- [ ] Android descubre el servicio BitChat de iOS en dos teléfonos físicos.
- [ ] Un `DISTRESS` originado en iOS aparece en el repositorio Android.
- [ ] Un `DISTRESS` originado en Android aparece en `Paquetes` de iOS.
- [ ] Un `SAFE` se intercambia en ambos sentidos.
- [ ] Un paquete fragmentado se reensambla entre plataformas.

La última validación requiere dispositivos físicos; el simulador no ofrece un
transporte BLE Android↔iOS fiable.

Estas pruebas requieren dos o tres iPhones reales; el simulador no reproduce el transporte BLE entre dispositivos de forma fiable.
