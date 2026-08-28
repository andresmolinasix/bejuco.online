# Criterios de aceptación iOS

## Automatizados

- [x] El proyecto abre como `Bejuco.xcodeproj`.
- [x] La app compila para iOS Simulator.
- [x] El envelope se serializa y deserializa con campos estables.
- [x] Una firma válida se verifica después de incrementar `hopCount`.
- [x] El almacén deduplica paquetes con el mismo `messageId`.

## Manuales en dispositivo físico

- [ ] A → B transfiere un paquete `DISTRESS` por BLE.
- [ ] El paquete persiste en A y B después de cerrar la app.
- [ ] Bluetooth OFF/ON no elimina el paquete.
- [ ] B → C funciona sin que A vuelva a estar presente.
- [ ] Copias múltiples del paquete producen un único registro.
- [ ] Un paquete vencido no se retransmite.
- [ ] `hopCount`/`hopLimit` detienen el relay.
- [ ] C entrega el lote al backend cuando vuelve Internet.

Estas pruebas requieren dos o tres iPhones reales; el simulador no reproduce el transporte BLE entre dispositivos de forma fiable.

