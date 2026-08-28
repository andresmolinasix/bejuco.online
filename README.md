# Bejuco

**Comunicación de emergencia que sigue funcionando cuando la conectividad falla.**

En un terremoto, una persona puede estar a pocos metros de ayuda y, aun así,
quedar incomunicada por la caída de red móvil e Internet. Bejuco convierte
teléfonos Android cercanos en una red Bluetooth Low Energy que transporta
alertas de auxilio de nodo a nodo, sin cuentas ni infraestructura local.

## Qué demuestra

- Un aviso **DISTRESS** firmado viaja por Bluetooth entre teléfonos cercanos.
- Cada nodo valida, deduplica y persiste el paquete antes de aceptarlo.
- La alerta sobrevive cierre o reinicio de la app: store-carry-forward local.
- Cuando vuelve Internet, el diseño permite sincronizar los avisos a la
  plataforma de respuesta sin reemplazar la red offline.

## Flujo

```text
Persona en riesgo
  → DISTRESS firmado
  → Android A ── BLE ── Android B ── BLE ── Android C
  → SQLite local en cada nodo
  → Cloud Run + PostgreSQL cuando un nodo recupera Internet
```

[Ver diagrama de arquitectura](https://github.com/andresmolinasix/bejuco-platform/blob/main/docs/architecture/system-diagram.md)

## Estado de la demo

| Capacidad | Estado |
| --- | --- |
| Paquete Bejuco Protocol v1 firmado (Ed25519) | Implementado |
| Persistencia y deduplicación local SQLite | Implementado y probado |
| Envío BLE físico Android A → B | Validado en hardware |
| Relay B → C sin A presente | Próxima validación |
| Ingesta cloud desde Android | En preparación |

## Arquitectura

- **Android / este repositorio:** Kotlin, BLE mesh, `EmergencyRelay`, SQLite y la futura sincronización.
- **Plataforma:** contrato del protocolo, API de ingesta, PostgreSQL e infraestructura GCP en [bejuco-platform](https://github.com/andresmolinasix/bejuco-platform).
- **Principio:** offline primero. La nube amplía la respuesta; no es requisito para pedir ayuda.

## Ejecutar

Requiere Android Studio, JDK 21 y Android SDK.

```bash
git clone git@github.com:andresmolinasix/bejuco.online.git
cd bejuco.online
./gradlew assembleDebug
./gradlew testDebugUnitTest
```

Instalar en un teléfono Android:

```bash
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

Para la prueba de red se requieren al menos dos teléfonos Android con Bluetooth
habilitado. El botón de prueba DISTRESS está disponible en ajustes de depuración.

## Repositorios

- [bejuco.online](https://github.com/andresmolinasix/bejuco.online): aplicación Android y red BLE.
- [bejuco-platform](https://github.com/andresmolinasix/bejuco-platform): arquitectura, protocolo e infraestructura.

Basado en [BitChat Android](https://github.com/permissionlesstech/bitchat-android).
Este proyecto se distribuye bajo [GPL-3.0](LICENSE.md).
