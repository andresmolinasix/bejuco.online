# Topología de repositorios de Bejuco

## Estado

Esta decisión debe respetarse al crear código, documentación o infraestructura.

## Decisión

Bejuco se organiza en repositorios independientes. No se usará un monorepo que contenga las implementaciones móvil, iOS y plataforma como subcarpetas.

La estructura definida en los documentos de arquitectura es:

```text
github.com/bejuco/
├── bejuco-android       ← implementación Android
├── bejuco-platform      ← protocolo, backend, dashboard, base de datos e infraestructura
└── bejuco-ios           ← implementación posterior al MVP
```

El nombre público de la aplicación es **Bejuco**.

## Convención actual

El repositorio `andresmolinasix/bejuco.online` se usa como la implementación Android prevista como `bejuco-android`. Esta es una convención de nombre del equipo; no reemplaza la separación de repositorios indicada arriba.

## Responsabilidades

### Implementación Android (`bejuco-android` / `bejuco.online`)

- Aplicación Android en Kotlin.
- BLE, descubrimiento de peers, sincronización y relay.
- Persistencia local con Room/SQLite.
- Paquetes de emergencia y store-carry-forward.
- Integración posterior con el gateway de Internet.
- BitChat Android se mantiene como remoto `upstream`; no se importa dentro de una subcarpeta.

### `bejuco-platform`

- Especificación canónica e independiente: `Bejuco Protocol v1`.
- Vectores de prueba del protocolo.
- Backend, dashboard, migraciones de base de datos e infraestructura.

### `bejuco-ios`

- Implementación futura en Swift/SwiftUI/Core Bluetooth.
- Consume `Bejuco Protocol v1`; no depende del código Kotlin.

## Restricciones explícitas

No crear dentro de `bejuco.online` las carpetas siguientes como si fueran otros productos:

```text
bejuco.online/
├── bejuco-ios/       # No
├── bejuco-platform/  # No
└── mobile/android/   # No
```

El código Android de Bejuco vive en la raíz del repositorio, partiendo de la estructura Gradle de BitChat. Los repositorios de plataforma e iOS se crearán como repositorios hermanos cuando el MVP Android y la primera versión del protocolo lo justifiquen.

## Fases

`bejuco-android` y `bejuco-platform` forman parte de la arquitectura inicial y pueden desarrollarse en paralelo. `bejuco-ios` se crea después de validar Android y estabilizar `Bejuco Protocol v1`.

Los documentos de arquitectura no definen un repositorio único ni un formato específico de entrega para la hackathon.
