# Protocolo de contexto para agentes

Todo agente que trabaje en Bejuco debe leer, antes de proponer o modificar código:

1. `docs/output/codex/INDEX.md`.
2. `docs/2-MAESTRO_DE_ARQUITECTURA.md`.
3. `docs/3-BEJUCO_IMPLEMENTACION_REPOSITORIO_V1.md`.
4. `docs/4-REPOSITORY_TOPOLOGY.md`.

## Cumplimiento obligatorio

- Respetar Android nativo como plataforma inicial del MVP.
- Mantener BitChat Android como base técnica y remoto `upstream`.
- Priorizar persistencia, deduplicación, sincronización BLE y *store-carry-forward*.
- Mantener separados los repositorios Android, plataforma e iOS.
- No crear un monorepo ni anidar `bejuco-platform`, `bejuco-ios` o `mobile/android` dentro del repositorio Android.
- Tratar `Bejuco Protocol v1` como contrato independiente de Kotlin, Swift y el backend.
- No agregar al MVP chat, Nostr, blockchain, ESP32, multimedia o iOS antes de validar el hito A → B → C.

## Regla de decisión

Una propuesta que contradiga los documentos normativos o el índice debe señalar la contradicción, justificar el cambio y esperar una decisión explícita del equipo antes de implementarse.

## Commits

Usar Conventional Commits: `tipo: descripción breve`.

- `feat`: nueva funcionalidad para usuario.
- `fix`: corrección de error para usuario.
- `docs`: cambios de documentación.
- `style`: formato; sin cambio de producción.
- `refactor`: refactor de producción.
- `test`: cambios de pruebas; sin cambio de producción.
- `chore`: mantenimiento; sin cambio de producción.
