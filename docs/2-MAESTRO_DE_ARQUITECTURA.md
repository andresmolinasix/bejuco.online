Sí. Si la intención es empezar a construir **ya**, yo congelaría varias decisiones arquitectónicas desde hoy para evitar que dentro de dos semanas terminen rehaciendo el proyecto.

Mi recomendación base es:

> **Android nativo primero + dos repositorios + GCP serverless + PostgreSQL/PostGIS + Terraform + trunk-based Git.**

No empezaría simultáneamente Android/iOS, ni React Native, ni Kubernetes, ni una arquitectura de microservicios.

## 1. Aplicación: Android nativo primero

Para este proyecto elegiría **Kotlin + Android nativo** como plataforma del MVP.

La razón no es la interfaz. El problema difícil de Bejuco está aquí:

```text
BLE scanning
BLE advertising
background execution
foreground services
reconnection
GATT
battery management
Bluetooth ON/OFF
process death
persistent storage
store-carry-forward
```

Android tiene APIs y reglas bastante específicas para BLE en background: `BluetoothLeScanner`, `PendingIntent`, `WorkManager`, foreground services tipo `connectedDevice`, etc. ([Android Developers][1])

iOS tiene su propio modelo con Core Bluetooth y reglas diferentes de ejecución en background; incluso iOS 26 incorpora comportamientos adicionales vinculados a Live Activities. ([Apple Developer][2])

Por eso React Native no elimina la complejidad principal. Terminarían haciendo:

```text
React Native UI
      │
      ▼
Native Android BLE module
      │
      ▼
Kotlin
```

y después:

```text
React Native UI
      │
      ▼
Native iOS BLE module
      │
      ▼
Swift
```

Es decir: mantienen React Native **más** dos implementaciones nativas.

Para un e-commerce eso puede tener sentido. Para Bejuco, no.

### Orden que usaría

```text
FASE 1                FASE 2
─────────────────     ─────────────────
Android               iOS
Kotlin                Swift
Jetpack Compose       SwiftUI
Room / SQLite         SQLite/CoreData
Android BLE           Core Bluetooth
```

Primero demuestran:

```text
Android A
    ↓ BLE
Android B
    ↓ BLE
Android C
    ↓ Internet
GCP
```

Después hacen:

```text
Android A
    ↓ BLE
iPhone B
    ↓ BLE
Android C
```

Ahí la especificación de **Bejuco Protocol v1** es lo que garantiza interoperabilidad.

---

# 2. No haría un gran monorepo para todo

Como están partiendo de BitChat Android, yo usaría **dos repositorios ahora**.

```text
github.com/bejuco/
│
├── bejuco-android
│
└── bejuco-platform
```

Y más adelante:

```text
github.com/bejuco/
│
├── bejuco-android
├── bejuco-ios
└── bejuco-platform
```

Esto es mejor que meter Android + iOS + backend + Terraform en un mismo repositorio porque `bejuco-android` conserva una relación clara con su upstream, BitChat.

### `bejuco-android`

Inicialmente mantendría bastante de la estructura existente y comenzaría a separar Bejuco:

```text
bejuco-android/
│
├── app/
│   └── src/main/java/...
│
├── mesh/
│   ├── discovery
│   ├── transport
│   ├── peer
│   └── relay
│
├── sync/
│   ├── inventory
│   ├── gossip
│   └── deduplication
│
├── protocol/
│   ├── packet
│   ├── codec
│   └── signature
│
├── emergency/
│   ├── EmergencyMode
│   ├── DistressMessage
│   └── SafetyStatus
│
├── storage/
│   ├── MessageEntity
│   ├── MessageDao
│   └── BejucoDatabase
│
├── gateway/
│   ├── InternetDetector
│   ├── UploadQueue
│   └── GcpGateway
│
├── security/
│
├── ui/
│
└── docs/
```

No intentaría refactorizar todo BitChat el primer día.

Primero aislaría:

```text
BitChat existing BLE
       │
       ▼
Bejuco protocol
       │
       ▼
persistent emergency store
       │
       ▼
Internet gateway
```

Después se puede ir eliminando chat, Nostr, canales, archivos, etc.

---

# 3. El segundo repo sería `bejuco-platform`

Ahí sí usaría un pequeño monorepo:

```text
bejuco-platform/
│
├── backend/
│   ├── src/
│   ├── tests/
│   └── Dockerfile
│
├── dashboard/
│
├── database/
│   └── migrations/
│
├── protocol/
│   ├── bejuco-v1.md
│   ├── packet-types.md
│   ├── examples/
│   └── test-vectors/
│
├── infra/
│   └── terraform/
│       ├── modules/
│       └── environments/
│           ├── dev/
│           └── prod/
│
├── docs/
│   ├── architecture/
│   ├── threat-model/
│   └── adr/
│
└── .github/
    └── workflows/
```

Hay una carpeta especialmente importante:

```text
protocol/
```

No debe depender de Kotlin, Swift o TypeScript.

Debe decir:

```text
Bejuco Protocol v1

messageId
version
type
sender
timestamp
expiresAt
location
priority
hopCount
hopLimit
payload
signature

serialización
hash
firma
deduplicación
TTL
ACK
```

Así:

```text
             Bejuco Protocol v1
                     │
        ┌────────────┼────────────┐
        ▼            ▼            ▼
     Android        iOS          ESP32
      Kotlin        Swift          C++
```

Ésa es la parte que realmente debe ser cross-platform.

---

# 4. Infraestructura GCP: la haría mucho más pequeña de lo que parece

Para el MVP no necesitan GKE, Compute Engine ni Kafka.

Usaría esto:

```text
                    INTERNET RECUPERADO
                           │
                           ▼
                    ┌─────────────┐
                    │  Cloud Run  │
                    │  ingest-api │
                    └──────┬──────┘
                           │
             ┌─────────────┴─────────────┐
             ▼                           ▼
       Cloud SQL                     Pub/Sub
      PostgreSQL                    [posterior]
       + PostGIS
             │
             ▼
      ┌──────────────┐
      │ Dashboard API│
      │  Cloud Run   │
      └──────┬───────┘
             ▼
        Dashboard
```

### El componente central: Cloud Run

El teléfono que finalmente encuentra Internet hace:

```http
POST /v1/messages/batch
```

por ejemplo:

```json
{
  "messages": [
    {
      "messageId": "01K...",
      "type": "DISTRESS",
      "createdAt": "...",
      "lat": 5.69,
      "lon": -76.66,
      "payload": {},
      "signature": "..."
    }
  ]
}
```

Cloud Run encaja muy bien porque autoscalea con las solicitudes y puede incluso escalar a cero; también permite configurar instancias mínimas y máximas. ([Google Cloud Documentation][3])

Para producción probablemente pondría:

```text
min instances = 1
```

y establecería un `max instances` para controlar costos y evitar que un ataque produzca escalamiento indefinido.

---

# 5. PostgreSQL + PostGIS es la base de datos correcta

Aquí evitaría Firestore.

Su dominio naturalmente terminará preguntando:

```text
¿cuántos SOS existen en este radio?

¿qué solicitudes existen alrededor de Istmina?

¿qué centro de acopio está más cerca?

¿qué solicitudes existen dentro de este polígono?

¿qué zonas presentan más necesidades?

¿qué solicitudes siguen activas?
```

Eso es geoespacial.

Cloud SQL for PostgreSQL soporta oficialmente **PostGIS** en todas sus versiones principales soportadas. ([Google Cloud Documentation][4])

Por ejemplo:

```sql
CREATE EXTENSION postgis;
```

Y pueden tener:

```sql
CREATE TABLE emergency_messages (
    message_id UUID PRIMARY KEY,
    event_id TEXT,
    message_type TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    received_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    location GEOGRAPHY(POINT, 4326),

    priority SMALLINT,
    payload JSONB,
    signature BYTEA
);
```

Entonces la deduplicación empieza trivialmente:

```sql
INSERT ...
ON CONFLICT (message_id)
DO NOTHING;
```

Eso responde directamente al caso:

```text
A → B → Gateway
 \ C → Gateway

Gateway recibe SOS #123 dos veces

PostgreSQL:
SOS #123 = 1
```

---

# 6. Agregaría una segunda tabla: `message_observations`

Ésta va a ser útil.

```text
emergency_messages
─────────────────────────
message_id
origin
created_at
location
payload
```

y:

```text
message_observations
─────────────────────────
message_id
gateway_id
received_at
hop_count
```

Así pueden saber:

```text
SOS #123
    ├── llegó por gateway D
    ├── llegó por gateway F
    └── llegó por gateway H
```

sin interpretar las copias como tres emergencias distintas.

Yo evitaría almacenar toda la ruta de personas por las que pasó el mensaje salvo que exista una razón operacional concreta; crea información de localización que probablemente no necesitan.

---

# 7. Pub/Sub sí, pero no es requisito para el día uno

Cloud Run puede insertar directamente en PostgreSQL.

Para el primer MVP:

```text
Phone
  ↓
Cloud Run
  ↓
PostgreSQL
```

Perfecto.

Cuando aparezcan procesos como:

```text
nuevo SOS
    ├── generar alerta
    ├── recalcular cluster
    ├── notificar dashboard
    ├── enviar autoridad
    └── detectar duplicados semánticos
```

entonces:

```text
Cloud Run
    │
    ├── PostgreSQL
    │
    └── Pub/Sub
           │
      ┌────┼─────┐
      ▼    ▼     ▼
    alert map analytics
```

Pub/Sub está específicamente diseñado para integrarse con servicios autoscalables como Cloud Run. ([Google Cloud Documentation][5])

Pero yo **no lo introduciría en el sprint inicial**.

---

# 8. Infraestructura GCP que crearía ahora

La arquitectura inicial sería:

```text
GCP PROJECT: bejuco-dev

Cloud Run
  bejuco-ingest-api

Cloud Run
  bejuco-dashboard

Cloud SQL
  PostgreSQL
  PostGIS

Secret Manager

Artifact Registry

Cloud Logging
Cloud Monitoring
```

Luego:

```text
GCP PROJECT: bejuco-prod
```

Misma infraestructura, creada por Terraform.

Artifact Registry es actualmente el registro recomendado de GCP para imágenes de contenedor y se integra directamente con Cloud Run. ([Google Cloud Documentation][6])

Y Cloud Run tiene integración administrada con Cloud SQL. ([Google Cloud Documentation][7])

---

# 9. Terraform desde el principio

Aquí sí invertiría tiempo desde el día uno.

No creen manualmente:

```text
Cloud Run
Cloud SQL
IAM
Artifact Registry
Secrets
```

desde la consola y luego intenten recordar qué hicieron.

Haría:

```text
infra/
└── terraform/
    ├── modules/
    │   ├── cloud-run/
    │   ├── cloud-sql/
    │   ├── artifact-registry/
    │   └── iam/
    │
    └── environments/
        ├── dev/
        └── prod/
```

Entonces:

```bash
terraform plan
terraform apply
```

reconstruye la plataforma.

Esto les va a ahorrar muchísimo trabajo cuando hagan:

```text
hackathon
demo
dev
staging
prod
```

---

# 10. Git: mantendría una estrategia extremadamente sencilla

No usaría:

```text
main
develop
staging
release
integration
feature
```

Eso es demasiado para este momento.

Usaría **trunk-based development**:

```text
main
  │
  ├── feature/persistent-message-store
  │
  ├── feature/distress-packet
  │
  ├── feature/ble-resync
  │
  ├── feature/gcp-gateway
  │
  └── fix/bluetooth-reconnect
```

Flujo:

```text
issue
  ↓
feature branch
  ↓
commit
  ↓
pull request
  ↓
tests
  ↓
main
```

`main` siempre debe compilar.

Nada de commits experimentales directamente en `main`.

---

# 11. Y mantendría BitChat como `upstream`

Esto es particularmente importante.

Su repositorio:

```text
origin
   ↓
github.com/bejuco/bejuco-android
```

Repositorio original:

```text
upstream
   ↓
github.com/permissionlesstech/bitchat-android
```

Entonces:

```bash
git remote -v
```

debería terminar aproximadamente así:

```text
origin    git@github.com:bejuco/bejuco-android.git
upstream  https://github.com/permissionlesstech/bitchat-android.git
```

Cuando BitChat arregle:

```text
BLE bug
Android 17 compatibility
background scanning
fragmentation
battery issue
```

ustedes pueden revisar:

```bash
git fetch upstream
```

y **cherry-pickear** el fix que les interese.

No intentaría hacer automáticamente:

```bash
git merge upstream/main
```

cada semana.

A medida que Bejuco diverja de BitChat va a ser cada vez más peligroso.

---

# 12. Congelen el commit inicial de BitChat

Esto lo haría literalmente el primer día.

Por ejemplo:

```bash
git tag bitchat-base-v1
git push origin bitchat-base-v1
```

Mejor aún:

```text
docs/upstream.md

BitChat base:
repository:
permissionlesstech/bitchat-android

commit:
4f828b...

date:
2026-08-...

reason:
Initial Bejuco BLE implementation
```

Entonces dentro de seis meses pueden responder:

> ¿de qué versión de BitChat salió esta implementación?

sin especular.

---

# 13. Hay un tema de licencia que tienen que decidir antes de desarrollar demasiado

Esto es importante.

Actualmente el archivo `LICENSE.md` de `bitchat-android/main` contiene **GNU GPL v3**. ([GitHub][8])

Existen textos inconsistentes en otras partes del proyecto respecto a public domain/licencia, pero **el archivo de licencia actual del repositorio Android es GPLv3**.

Eso significa que yo asumiría, conservadoramente:

> si Bejuco Android es una obra derivada del código de `bitchat-android` y ustedes distribuyen la aplicación, deben tratarla como GPLv3 y cumplir sus obligaciones de distribución de código fuente.

No es un problema si Bejuco va a ser open source.

De hecho puede ser perfectamente compatible con el propósito del proyecto.

Pero si su intención fuera:

```text
Bejuco Android = código propietario
```

entonces **no arrancaría haciendo fork directo**. Haría una implementación independiente tomando como referencia el protocolo/comportamiento, y revisaría jurídicamente la licencia antes de reutilizar código.

Es mejor resolver esta decisión ahora.

---

# 14. Seguridad del repositorio: cinco reglas desde el principio

Aquí mantendría la disciplina muy pequeña:

| Regla                            | Implementación               |
| -------------------------------- | ---------------------------- |
| `main` protegido                 | PR obligatorio               |
| Ningún secret en Git             | Secret Manager               |
| Ninguna JSON Service Account Key | Workload Identity Federation |
| CI antes de merge                | test + lint + build          |
| infraestructura versionada       | Terraform                    |

Especialmente evitaría totalmente:

```text
gcp-key.json
service-account.json
database-password.txt
.env.production
```

dentro del repositorio.

Para GitHub Actions → GCP, Google recomienda **Workload Identity Federation**, que permite que GitHub obtenga credenciales temporales mediante OIDC sin almacenar una service-account key permanente. ([Google Cloud Documentation][9])

Y los secretos de runtime van a Secret Manager, diseñado específicamente para claves, contraseñas, certificados y otras credenciales. ([Google Cloud Documentation][10])

La cadena queda:

```text
GitHub Actions
      │
      │ OIDC
      ▼
Workload Identity Federation
      │
      ▼
GCP Service Account
      │
      ▼
Artifact Registry
      │
      ▼
Cloud Run
```

**Cero claves GCP guardadas en GitHub.**

---

# 15. Yo congelaría esta arquitectura como V1

```text
                         BEJUCO V1

                 ┌────────────────────┐
                 │ Bejuco Protocol V1 │
                 └──────────┬─────────┘
                            │
           ┌────────────────┴──────────────┐
           │                               │
           ▼                               ▼
┌──────────────────────┐          ┌───────────────────┐
│    bejuco-android    │          │ bejuco-platform  │
│                      │          │                   │
│ Kotlin               │          │ Cloud Run         │
│ Jetpack Compose      │          │ PostgreSQL        │
│ Room                 │          │ PostGIS           │
│ BLE                  │          │ Terraform         │
│ Store/Carry/Forward  │          │ Dashboard         │
└──────────┬───────────┘          └─────────▲─────────┘
           │                                │
           │ BLE                            │ HTTPS
           ▼                                │
┌──────────────────────┐                    │
│ another Android      │────────────────────┘
│ Internet available   │
└──────────────────────┘


                FUTURO
                  │
        ┌─────────┴──────────┐
        ▼                    ▼
    bejuco-ios            ESP32
      Swift
```

Y **no movería estas decisiones durante el MVP**:

| Decisión             | V1                             |
| -------------------- | ------------------------------ |
| Mobile               | Android nativo / Kotlin        |
| BLE base             | BitChat Android                |
| Persistencia         | Room/SQLite                    |
| Arquitectura offline | Store-carry-forward            |
| Protocolo            | Bejuco Protocol v1             |
| Backend              | Cloud Run                      |
| DB                   | Cloud SQL PostgreSQL + PostGIS |
| Async                | Pub/Sub posteriormente         |
| Infraestructura      | Terraform                      |
| CI/CD                | GitHub Actions + WIF           |
| Git                  | `main` + feature branches      |
| iOS                  | Después del MVP                |
| React Native         | No                             |
| Kubernetes           | No                             |
| Blockchain           | No                             |
| ESP32                | No todavía                     |

### El primer sprint

Yo no empezaría por la pantalla del SOS.

Empezaría exactamente por esta secuencia:

```text
1. crear bejuco-android
2. congelar commit upstream
3. eliminar/desactivar Nostr
4. definir BejucoEnvelope v1
5. implementar Room
6. generar DISTRESS
7. guardar DISTRESS
8. A → BLE → B
9. guardar en B
10. Bluetooth OFF/ON
11. B → BLE → C
12. C recupera Internet
13. POST batch → Cloud Run
14. INSERT → PostgreSQL/PostGIS
15. verificar SOS en dashboard
```

**Cuando el punto 15 funcione después de apagar Bluetooth, matar apps y separar físicamente los teléfonos, tienen Bejuco V1.**

A partir de ahí sí agregaría `SAFE`, centros de acopio, `SUPPLY_REQUEST`, ESP32 y demás funcionalidades. Esta estructura además les permite que los cambios en el protocolo sean deliberados y versionados, en vez de quedar dispersos dentro del código Android.

[1]: https://developer.android.com/develop/connectivity/bluetooth/ble/background?hl=es&utm_source=chatgpt.com "Comunícate en segundo plano  |  Connectivity  |  Android Developers"
[2]: https://developer.apple.com/documentation/corebluetooth?changes=latest____3&language=objc&utm_source=chatgpt.com "Core Bluetooth | Apple Developer Documentation"
[3]: https://docs.cloud.google.com/run/docs/configuring?utm_source=chatgpt.com "Configure Cloud Run services  |  Google Cloud Documentation"
[4]: https://docs.cloud.google.com/sql/docs/postgres/extensions?hl=es&utm_source=chatgpt.com "Configurar extensiones de PostgreSQL  |  Cloud SQL for PostgreSQL  |  Google Cloud Documentation"
[5]: https://docs.cloud.google.com/pubsub/docs/push?utm_source=chatgpt.com "Push subscriptions  |  Pub/Sub  |  Google Cloud Documentation"
[6]: https://docs.cloud.google.com/artifact-registry/docs/overview?hl=es&utm_source=chatgpt.com "Información general de Artifact Registry  |  Google Cloud Documentation"
[7]: https://docs.cloud.google.com/sql/docs/postgres/connect-run?hl=es-419&utm_source=chatgpt.com "Conectarse desde Cloud Run  |  Cloud SQL for PostgreSQL  |  Google Cloud Documentation"
[8]: https://github.com/permissionlesstech/bitchat-android/blob/main/LICENSE.md "bitchat-android/LICENSE.md at main · permissionlesstech/bitchat-android · GitHub"
[9]: https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines?hl=es&utm_source=chatgpt.com "Configurar la federación de identidades de cargas de trabajo con las canalizaciones de implementación  |  Identity and Access Management (IAM)  |  Google Cloud Documentation"
[10]: https://docs.cloud.google.com/secret-manager/docs?utm_source=chatgpt.com "Secret Manager documentation  |  Google Cloud Documentation"
