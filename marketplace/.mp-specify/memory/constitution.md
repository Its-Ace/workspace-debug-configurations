<!--
  Sync Impact Report
  ==================
  Version change: 1.0.0 → 2.0.0
  Modified principles:
    - §I: Added full MVC layer mapping table and directory trees (from root constitution)
    - §II: Added HTTP method semantics, deviation documentation rule
    - §II-A: Promoted to full section with binding requirements list
    - §III: Added full service/category code tables with examples
    - §IV: Added log level definitions, structured JSON example, correlation ID details
    - §V: Added audit field table, retention periods by data type
    - §VI: Added RBAC roles table, JWT RS256 details, JWKS endpoint, header
      injection, Nafath SSO flow, three-layer enforcement detail
    - §VII: Added full Docker-only rules (container logs, .env only, no hardcoded vars)
    - §VIII: Added schema prefix conventions, migration branch labels
    - §IX: Added gRPC timeout values, dependency direction diagram, CloudEvents
      envelope, Kafka topic/event topology, projection table rules
  Added sections:
    - §X Security Controls (encryption, file upload, data residency)
    - §XI Financial Architecture (escrow, double-entry, gateway abstraction)
    - §XII Document Storage (pre-signed URLs, versioning, virus scanning)
    - §XIII Observability (ELK, Prometheus/Grafana, Sentry, health probes, ES sync)
    - §XIV Video Consultation (pluggable interface)
    - §XV Deployment & Infrastructure (K8s namespaces, HPA, PDB, multi-AZ, uptime)
    - PR Checklist with Severity Levels (P0/P1/P2)
    - CI Enforcement table
    - Weekly Architecture Review Gate
    - Monthly Service Health Audit
    - Boundary Violation Severity table
  Removed sections: None
  Templates requiring updates:
    - .specify/templates/plan-template.md ✅ aligned (Constitution Check section exists)
    - .specify/templates/spec-template.md ✅ aligned (user story + acceptance criteria)
    - .specify/templates/tasks-template.md ✅ aligned (phase structure compatible)
  Follow-up TODOs: None
-->

# Marketplace Services Constitution

## Core Principles

### I. Code Quality (NON-NEGOTIABLE)

All Python code MUST follow PEP 8 with a maximum line length of 120 characters.

- No dead code, commented-out blocks, or `print()` statements in committed code.
- All functions and classes MUST have descriptive names — abbreviations are
  forbidden unless industry-standard (e.g., `api`, `dto`, `grpc`, `sse`, `jwt`).
- Complexity MUST be justified; prefer readability over cleverness.
- Every FastAPI service MUST use Pydantic `BaseModel` for all request/response
  schemas.
- Business logic MUST live in the service layer — route handlers only orchestrate
  (thin routes, fat services).
- All async endpoints MUST use `async def` — never block the event loop with
  synchronous I/O.

#### I-A. MVC Directory Structure (MANDATORY)

All FastAPI microservices MUST follow an MVC (Model–View–Controller) internal
directory structure:

| MVC Layer      | FastAPI Equivalent                | Directory / File |
|----------------|-----------------------------------|------------------|
| **Model**      | SQLAlchemy ORM models             | `models/`        |
| **Model (DTO)**| Pydantic request/response schemas | `schemas/`       |
| **View**       | FastAPI route handlers            | `api/v1/`        |
| **Controller** | Business logic services           | `services/`      |
| —              | Data access layer                 | `repositories/`  |

**Standard service structure** (auth, documents, payments, notifications):

```
{service-name}/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI app factory
│   ├── config.py            # Environment configuration (from .env)
│   ├── error_codes.py       # Centralized error code definitions
│   ├── models/              # M — SQLAlchemy ORM models
│   │   └── __init__.py
│   ├── schemas/             # M (DTO) — Pydantic request/response models
│   │   └── __init__.py
│   ├── services/            # C — Business logic (fat services)
│   │   └── __init__.py
│   ├── repositories/        # Data access layer (queries, CRUD)
│   │   └── __init__.py
│   ├── api/                 # V — Route handlers (thin routes)
│   │   ├── __init__.py
│   │   └── v1/
│   │       ├── __init__.py
│   │       └── router.py
│   ├── events/              # Kafka producers/consumers
│   │   └── __init__.py
│   ├── grpc/                # gRPC client/server definitions
│   │   └── __init__.py
│   └── core/                # Service-specific utilities (deps, security, etc.)
│       └── __init__.py
├── migrations/              # Alembic migrations
│   ├── env.py
│   └── versions/
├── tests/
│   ├── unit/
│   └── integration/
├── Dockerfile
├── pyproject.toml
└── alembic.ini
```

**Modular service structure** (application-service):

```
application-service/
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── config.py
│   ├── error_codes.py
│   ├── api/
│   │   └── v1/
│   │       └── router.py    # Aggregates all module routes
│   ├── events/
│   ├── grpc/
│   └── modules/
│       └── {module_name}/   # e.g., serviceprovider, admin, orders, reviews, audit
│           ├── __init__.py
│           ├── models/      # SQLAlchemy ORM models (one file per entity)
│           ├── schemas/     # Pydantic request/response DTOs
│           ├── services/    # Business logic
│           ├── repositories/ # Data access layer
│           ├── api/         # FastAPI route handlers
│           ├── ports/       # Port Protocols for cross-module contracts
│           ├── events/      # EventBus publishers/subscribers
│           ├── config.py    # Module-specific BaseSettings
│           └── health.py    # Module health-check endpoint
├── migrations/
├── tests/
├── Dockerfile
├── pyproject.toml
└── alembic.ini
```

**Rules:**
- Route handlers MUST be thin — only request parsing, dependency injection, and
  response formatting. No business logic.
- Business logic MUST live in `services/`.
- Database queries MUST live in `repositories/` — services
  MUST NOT contain raw SQL or direct ORM queries.
- Pydantic schemas MUST be separated from SQLAlchemy models — never expose ORM
  models directly in API responses.
- Cross-module communication within application-service MUST go through Port
  Protocols (`ports/`) — never import another module's repository or service directly.
- Each module MAY define its own `config.py` (BaseSettings) and `health.py`.

### II. REST API Consistency

All external API endpoints MUST conform to a uniform response envelope:

- **Success**: `{"code": 200, "result": {...}}`
- **Error**: `{"code": 4xx/5xx, "error_code": "SMP-SVC-CAT-NNN", "message": "..."}`

Any endpoint that bypasses this format MUST document why explicitly in a code
comment.

- HTTP methods MUST be semantically correct: GET for reads, POST for creation,
  PUT/PATCH for updates, DELETE for removals. No tunneling mutations through GET.
- Endpoint URLs MUST use kebab-case, be plural, and be versioned (`/api/v1/...`).
- All list endpoints MUST support pagination, filtering, and sorting.
- Rate limiting MUST be enforced at the API Gateway (Gravitee) level.

#### II-A. OpenAPI / Swagger (MANDATORY — API-FIRST)

Marketplace is an API-first platform. All consumers — Frontend (Nuxt.js),
Tenant Integrations (e.g., Merath), and the API Gateway — depend on API
contracts.

Every microservice MUST expose:
- **Swagger UI** at `/docs` — interactive API explorer.
- **ReDoc** at `/redoc` — clean, readable API reference.
- **OpenAPI JSON** at `/openapi.json` — machine-readable spec for tooling.

Binding requirements:
- OpenAPI specs are the **single source of truth** for all API contracts.
- Specs MUST be designed and reviewed **before** implementation begins.
- Every Pydantic schema MUST include `model_config` with `json_schema_extra`
  examples.
- Every endpoint MUST document success and error responses with OpenAPI
  `responses`.
- Tags MUST group endpoints by resource/module.
- Versioned spec exports MUST be maintained in `docs/api/{service-name}/`.
- CI MUST validate that live `/openapi.json` matches the committed spec.
- Frontend developers MUST use Swagger UI as the primary API reference.
- Client SDKs (TypeScript for FE, Python for integrations) MAY be auto-generated
  from specs.

### III. Error Code System

All error responses MUST use the structured format:
`SMP-{SERVICE}-{CATEGORY}-{CODE}`

**Service codes:**

| Code   | Service                        |
|--------|--------------------------------|
| `AUTH` | Auth Service (RBAC)            |
| `CORE` | Core Service (all modules)     |
| `USR`  | Core — ServiceProvider module  |
| `ADM`  | Core — Admin module            |
| `ORD`  | Core — Order & Workflow module |
| `REV`  | Core — Reviews module          |
| `AUD`  | Core — Audit module            |
| `PAY`  | Payments Service               |
| `DOC`  | Documents Service              |
| `NTF`  | Notifications Service          |
| `GW`   | API Gateway                    |

**Category codes:**

| Code   | Meaning                  |
|--------|--------------------------|
| `AUTH` | Authentication failure   |
| `PERM` | Permission / RBAC        |
| `VAL`  | Input validation         |
| `DATA` | Data not found / conflict|
| `DB`   | Database error           |
| `CONN` | Connection / timeout     |
| `CFG`  | Configuration error      |
| `SYS`  | System / infra failure   |
| `INTG` | External integration     |
| `BIZ`  | Business rule violation  |
| `ESC`  | Escrow / payment logic   |

Error codes MUST be defined in a centralized `error_codes.py` within each
service — not inline in route handlers.

Examples: `MP-AUTH-AUTH-001` (invalid credentials), `MP-ORD-BIZ-003` (order not
in biddable state), `MP-PAY-ESC-001` (escrow release failed).

### IV. Logging Standards

**Logger naming convention:** `mp.{service_name}.{module}` (e.g.,
`mp.orders.workflow`, `mp.payments.escrow`). Every service MUST use this
namespace.

**Log levels:**
- `DEBUG` — dev only, never in production.
- `INFO` — normal operations (request received, state transitions, events
  published).
- `WARNING` — permission denials, throttled requests, degraded fallbacks.
- `ERROR` — failed operations, unhandled exceptions, integration failures.
- `CRITICAL` — system failures, data corruption, circuit breaker open.

**Log format (structured JSON):**
```json
{
  "timestamp": "2026-03-17T12:00:00.000Z",
  "level": "INFO",
  "logger": "mp.orders.workflow",
  "trace_id": "abc-123",
  "causation_id": "def-456",
  "user_id": "uuid",
  "tenant_id": "uuid",
  "message": "Order state transitioned",
  "extra": {}
}
```

**Correlation ID propagation:** Every request MUST carry a `X-Trace-Id` header.
If not present, the API Gateway generates one. All downstream gRPC and Kafka
calls MUST propagate `mptraceid` and `mpcausationid`.

**Sensitive data** (passwords, tokens, national IDs, bank account numbers) MUST
NEVER appear in log output. Use PII redaction middleware.

Control via env var: `LOG_LEVEL=INFO` (default).

### V. Audit Logging

Every state-changing operation MUST be audit-logged with the following fields:

| Field        | Description                          |
|--------------|--------------------------------------|
| `user_id`    | Authenticated user UUID              |
| `role`       | User role at time of action          |
| `tenant_id`  | Tenant context                       |
| `timestamp`  | UTC ISO 8601                         |
| `action`     | Action type (e.g., `ORDER_CREATED`)  |
| `resource`   | Resource type + ID                   |
| `params`     | Sanitized request parameters         |
| `result`     | Success / failure + error code       |
| `ip`         | Client IP address                    |
| `user_agent` | Client user agent                    |

Audit records are **append-only** — no updates or deletes permitted.

**Retention periods:**

| Data Type             | Retention                    |
|-----------------------|------------------------------|
| Financial records     | 7 years (SAMA requirement)   |
| Other audit records   | 3 years                      |

Audit logs MUST be immutable, timestamped to millisecond precision (NTP-synced),
and correlated via trace ID across services.

**Compliance events that MUST be audit-logged:** authentication (login, logout,
failed attempts, token refresh, password changes), authorization (access denied,
role changes), data access (sensitive data reads), administrative actions (KYC,
disputes, bans), financial operations (all payment/escrow/refund actions).

### VI. Authentication & Authorization

- All authentication is handled by the **Auth Service** with custom JWT-based
  authentication.
- User identity is established via **Nafath SSO** (Saudi national digital
  identity).
- Access tokens are **JWT** (short-lived: 15–30 min). Refresh tokens are opaque,
  stored server-side in Redis for revocation.
- Every API endpoint MUST validate the JWT via Gravitee or a FastAPI dependency —
  no unprotected endpoints except public catalog search and health checks.
- Templates, frontend routes, and UI elements MUST NOT be the sole authorization
  gate.
- Auth Service owns all token lifecycle (issuance, refresh, revocation) — no
  external identity provider runtime dependency beyond Nafath SSO for initial
  identity verification.

#### VI-A. RBAC Roles

| Role       | Access Scope                                                            |
|------------|-------------------------------------------------------------------------|
| `user`     | Own profile, own orders, own documents, own payments, catalog search, review submission |
| `provider` | Own business profile, received leads/proposals, assigned orders, order-specific documents, own earnings, review submission |
| `admin`    | All platform data (read/write), KYC queue, dispute resolution, template management, finance dashboards, system health |

#### VI-B. Three-Layer Authorization Enforcement

1. **API Gateway (Gravitee):** Route-level RBAC — blocks unauthorized roles from
   entire service paths.
2. **Service Endpoint:** FastAPI dependency checks `user.role` and
   `user.permissions` against endpoint requirements.
3. **Resource Level:** Row-level security — queries scoped to `user_id` /
   `tenant_id` / `order_id` so users see only their own data.

#### VI-C. JWT Implementation (RS256)

JWT payload structure:
```json
{
  "sub": "user-uuid",
  "roles": ["vendor", "buyer"],
  "permissions": ["products:read", "products:write", "orders:read"],
  "tenant_id": "tenant-uuid",
  "iat": 1742169600,
  "exp": 1742173200,
  "iss": "mp-auth-service"
}
```

- Auth Service holds the **private key** (signs tokens).
- Public key exposed via `GET /auth/.well-known/jwks.json` (cached 5 min).
- Access token TTL: 15–30 min. Refresh token TTL: 7–30 days (stored in Redis).

#### VI-D. API Gateway Header Injection

Gravitee validates JWT and injects trusted headers to downstream services:

| Header               | Source Claim   |
|----------------------|----------------|
| `X-User-ID`         | `sub`          |
| `X-User-Roles`      | `roles`        |
| `X-User-Permissions` | `permissions` |
| `X-Tenant-ID`       | `tenant_id`    |

Gateway routing:

| Endpoint Pattern       | Target Service                         |
|------------------------|----------------------------------------|
| `/api/v1/auth/*`       | Auth Service                           |
| `/api/v1/orders/*`     | Core Service (Orders module)           |
| `/api/v1/providers/*`  | Core Service (ServiceProvider module)  |
| `/api/v1/admin/*`      | Core Service (Admin module)            |
| `/api/v1/payments/*`   | Payments Service                       |
| `/api/v1/documents/*`  | Documents Service                      |
| `/api/v1/reviews/*`    | Core Service (Reviews module)          |

Gateway also handles rate limiting, CORS, and request size limits.

#### VI-E. Nafath SSO Flow

Nafath uses OTP with 2-digit random confirmation in the Nafath app:

1. Frontend sends `POST /login/otp` with `social_id`.
2. Backend calls Nafath API, receives `transId` + `random` (2-digit number).
3. Backend stores `{transId, random, social_id}` in Redis (TTL: 300s).
4. Frontend shows the random number to user; user confirms in Nafath app.
5. Backend polls Nafath `checkstatus` endpoint (server-side, 5s intervals, max
   45s / 9 attempts).
6. On `COMPLETED` — create/update user, generate JWT tokens.
7. On `REJECTED` or `EXPIRED` — return error.

Server-side polling is mandatory — frontend MUST NOT poll Nafath directly.

### VII. Docker-Only Development

All development, debugging, and management commands MUST run inside Docker
containers.

- Never run `uvicorn`, `alembic`, or `pytest` directly on the host machine.
- Use `make <command>` or `docker compose exec <service> <command>` for all
  operations.
- Container logs are the primary debugging surface.
- Local environment variables MUST be set in `.env` only — never hardcoded.
- Docker Compose is the only supported local development environment.

### VIII. Database Rules

- **Database-per-service** — each microservice owns its database. No
  cross-service direct DB access (ADR-003).
- All migrations managed by **Alembic** per service.
- Migrations MUST be reviewed for reversibility before merging.
- Financial data (escrow, transactions, wallet) MUST use ACID transactions —
  never eventual consistency for money movement.
- Connection pooling is mandatory (`asyncpg` with SQLAlchemy async).

#### VIII-A. Database Schema Prefix Conventions (core_db)

| Module            | Table Prefix | Purpose                                      |
|-------------------|--------------|----------------------------------------------|
| ServiceProvider   | `sp_`        | Provider profiles, employees, licenses       |
| Admin             | `adm_`       | Tenant management, service templates         |
| Orders            | `ord_`       | Order lifecycle, workflows, leads/proposals  |
| Reviews           | `rev_`       | Ratings and moderation queue                 |
| Audit             | `aud_`       | Append-only audit trail                      |

Alembic manages migrations with branch labels per module. Each module maintains
migration files independently. Any migration that affects another service's
schema is rejected unconditionally.

### IX. Inter-Service Communication

- **External → Services:** REST/HTTP via Gravitee API Gateway (ADR-002).
- **Service → Service (sync):** gRPC only — never REST between services
  (ADR-002).
- **Service → Service (async):** Kafka with CloudEvents v1.0 envelope (ADR-002).
- No synchronous (gRPC) cycles — if A calls B via gRPC, B MUST NOT call A via
  gRPC. Use Kafka for the reverse direction.

#### IX-A. gRPC Rules

- gRPC calls MUST have explicit timeout: 5s read / 10s batch / 10s mutation.
- Every gRPC client MUST have a `@circuit` breaker decorator with recorded
  open/close metrics.
- Graceful degradation MUST be implemented if a service is unavailable.
- Batch gRPC methods MUST exist for any list-context lookup (no N+1 calls).
- Proto changes MUST be backward-compatible (additive only). Enforced by
  `buf lint` + `buf breaking` in CI.

#### IX-B. Kafka & CloudEvents

Kafka consumers MUST be idempotent (upsert, not insert; event ID deduplication).

**CloudEvents v1.0 envelope (MANDATORY):**
```json
{
  "specversion": "1.0",
  "id": "evt-550e8400-e29b-41d4-a716-446655440000",
  "source": "mp/orders-service",
  "type": "com.mp.order.order.completed",
  "datacontenttype": "application/json",
  "time": "2026-03-08T10:00:00.000Z",
  "subject": "order/d4e5f6a7-b8c9-0123-def0-456789012345",
  "mptraceid": "trace-abc123",
  "mpcausationid": "evt-previous-event-id",
  "data": { }
}
```

#### IX-C. Kafka Event Topology

| Topic                | Producer        | Consumers                                    | Key Events                                            |
|----------------------|-----------------|----------------------------------------------|-------------------------------------------------------|
| `mp.auth.events`     | Auth            | Core (ServiceProvider), Notifications, Admin | `user.registered`, `kyc.approved`, `kyc.rejected`, `user.suspended` |
| `mp.order.events`    | Core (Orders)   | Payments, Documents, Reviews, Admin, Notifications | `order.created`, `order.completed`, `order.cancelled`, `order.disputed`, `step.completed` |
| `mp.payment.events`  | Payments        | Core (Orders), Notifications, Admin          | `escrow.held`, `escrow.released`, `refund.processed`, `invoice.generated` |
| `mp.admin.events`    | Core (Admin)    | Core (Orders), Notifications                 | `service.created`, `service.updated`, `service.suspended` |
| `mp.document.events` | Documents       | Core (Orders), Notifications                 | `document.uploaded`, `document.expiring`              |
| `mp.review.events`   | Core (Reviews)  | Admin, ServiceProvider, Notifications        | `review.published`, `review.moderated`                |

#### IX-D. Projection Tables

- Projection tables are read-only within the owning service — updated
  exclusively by Kafka consumers.
- Stale data is acceptable (lag by seconds) except for financial data — always
  use gRPC for payment status.
- Cache miss falls back to gRPC; backfill the projection on response.
- Projection tables store only fields needed for composition (`display_name`,
  `avatar`, `rating`).
- All projection consumers handle duplicate events gracefully (upsert, not
  insert).
- Financial data MUST NEVER be cached or projected — always fetched live from
  Payments via gRPC.

### X. Security Controls

#### X-A. Encryption

| Control              | Implementation                                          |
|----------------------|---------------------------------------------------------|
| **At Rest**          | AES-256 via Alibaba Cloud KMS. RDS TDE. OSS SSE-KMS. Kafka log encryption. |
| **In Transit**       | TLS 1.2+ for all external and internal communication. mTLS between services (Phase 2). |
| **Secrets**          | Alibaba Cloud KMS + Kubernetes Secrets (encrypted at rest). NO credentials in source code or images. |

#### X-B. Input Validation & File Upload

- Pydantic models validate ALL API request/response payloads at system
  boundaries.
- File uploads: validate MIME type against whitelist, enforce size limits per
  document type, virus scan via ClamAV sidecar or OSS post-upload trigger.
  Infected files quarantined and reported to Documents Service.

#### X-C. Data Residency

All data stores provisioned in Alibaba Cloud Saudi Arabia region only. No data
replication outside KSA. Compliance with Saudi Personal Data Protection (PDP)
Law.

### XI. Financial Architecture

- **Escrow-first model** — all order payments flow through an escrow mechanism
  within Payments Service. Funds held until order completion + user approval
  triggers release.
- **Double-entry bookkeeping** — immutable transaction log. Separate escrow
  ledger for fund accounting.
- **Gateway abstraction** — all payment gateways (Edaat, BankHubPro, future
  additions) behind a `PaymentGatewayInterface`. No core logic couples to a
  specific gateway.
- **Commission/VAT handling** — calculated per transaction, visible in invoices.
- **Reconciliation** — regular jobs between Payments Service and actual payment
  gateways. Immutable audit trail for all fund movements.
- Financial data MUST NEVER be cached, projected, or stored in denormalized
  form. Always fetched live from Payments via gRPC.
- SAMA compliance requirements enforced.

### XII. Document Storage

- **Primary store:** Alibaba Cloud OSS (Saudi Arabia region), SSE-KMS encryption
  at rest, TLS in transit.
- **Pre-signed URLs** — Documents Service generates pre-signed URLs for client
  direct upload to OSS. Service manages metadata only.
- **Types:** KYC documents, order attachments, deliverables, invoices.
- **Versioning:** OSS versioning enabled. Document Service tracks version
  metadata in PostgreSQL.
- **Lifecycle policies:** OSS lifecycle for automatic cleanup of expired
  documents. Expiration triggers automated alerts via Kafka.
- **Virus scanning:** Post-upload via ClamAV sidecar or OSS event trigger.
  Infected files quarantined.

### XIII. Observability

#### XIII-A. Phase 1 (Current)

| Component         | Tool                        | Purpose                                          |
|-------------------|-----------------------------|--------------------------------------------------|
| **Logging**       | ELK Stack (ES + Logstash + Kibana) | Centralized structured JSON logging, correlation IDs |
| **Metrics**       | Prometheus + Grafana        | Latency, throughput, error rates, CPU/memory, custom business metrics |
| **Health Checks** | Kubernetes Probes           | `/health` and `/ready` per service. Auto-restart on failure. |
| **Alerting**      | Grafana Alerting            | Threshold and anomaly-based alerts               |

#### XIII-B. Phase 2 (Future)

| Component              | Tool   | Purpose                                          |
|------------------------|--------|--------------------------------------------------|
| **Error Aggregation**  | Sentry | Real-time error aggregation, stack traces, release tracking |
| **UX Tracking**        | Sentry | Client-side error tracking, session replay       |

#### XIII-C. Elasticsearch Sync (Catalog Search)

- Catalog Service writes to PostgreSQL (source of truth), publishes events to
  Kafka.
- A Kafka consumer syncs data to Elasticsearch for search/filter queries.
- Sync lag target: **< 5 seconds**.
- Graceful degradation: if ES unavailable, fall back to PostgreSQL full-text
  search with reduced functionality.
- Index rebuild capability from Kafka topic replay.

### XIV. Video Consultation

Pluggable `VideoProviderInterface` in Core Service (Orders module):
- Methods: `create_session()`, `get_join_url()`, `cancel_session()`.
- Provider selected via configuration (Teams current; Zoom/Jitsi candidates).
- Self-hosted (Jitsi) for strict data residency or hosted (Teams) for
  convenience.
- Scheduling data stored in Orders DB. Session data is ephemeral.
- Feature parity across providers not guaranteed.

### XV. Deployment & Infrastructure

#### XV-A. Kubernetes Namespace Layout

| Namespace       | Contents                                                   |
|-----------------|------------------------------------------------------------|
| `ingress`       | NGINX Ingress Controller                                   |
| `gateway`       | Gravitee API Gateway                                       |
| `frontend`      | Nuxt.js SSR pods (HPA: 2 replicas)                        |
| `services`      | All 5 microservices (2+ replicas each, HPA configured)     |
| `observability` | Prometheus, Grafana, Sentry                                |
| `logging`       | ELK Stack (Logstash, Kibana — ES is managed)               |

#### XV-B. Scaling

- **HPA:** Configured on all services (CPU/memory + custom metrics). Target
  replicas: 2–10 per service.
- **PDB:** Minimum 1 pod per service always available during rolling updates.
- **Cluster Autoscaler:** Scales node pool on pending pod demand (multi-AZ).
- **Priority classes:** Auth, Payments, Orders are highest priority.

#### XV-C. High Availability

- Multi-AZ deployment across Alibaba Cloud Saudi Arabia region.
- ApsaraDB RDS multi-AZ with automated failover.
- Redis cluster mode, multi-AZ.
- All data in Saudi Arabia region only.

#### XV-D. Uptime Target

**Platform SLA: 99.9%** (~43 min downtime/month max).

## Tech Stack Constraints

| Layer          | Technology                                                  |
|----------------|-------------------------------------------------------------|
| Frontend       | Nuxt.js (Vue 3 Composition API) with SSR                   |
| Backend        | Python FastAPI (async) — 5 microservices + mp-common        |
| Services       | auth-service, application-service, documents-service, payments-service, notifications-service |
| Shared Library | mp-common (response envelope, error codes, logging, auth deps) |
| API Docs       | OpenAPI 3.1 / Swagger UI / ReDoc (MANDATORY per service)    |
| Database       | PostgreSQL (database-per-service), Redis, Elasticsearch     |
| Events         | Apache Kafka (CloudEvents v1.0)                             |
| Storage        | Alibaba Cloud OSS (SSE-KMS)                                |
| Orchestration  | Alibaba Cloud ACK (Kubernetes)                              |
| API Gateway    | Gravitee                                                    |
| Auth           | Custom Auth Service (JWT RS256) + Nafath SSO                |
| Monitoring     | Prometheus/Grafana, ELK Stack, Sentry                       |
| CI/CD          | GitHub Actions                                              |
| Cloud          | Alibaba Cloud (Saudi Arabia region)                         |
| Task Queue     | Celery with Redis broker (per-service where needed)         |

- **No new dependencies** MUST be added without a corresponding ADR entry in
  `docs/architecture/ADRs/`.
- All development MUST run inside Docker containers. Use `make <command>` or
  `docker compose exec`.

## Development Workflow

- All feature work MUST be done on `feature/` branches; hotfixes on `hotfix/`
  branches.
- Before a PR is opened, the author MUST verify:
  1. No linting errors (`ruff` passes with 120-char line length).
  2. All endpoints have Pydantic request/response models.
  3. All endpoints are permission-gated (RBAC role or FastAPI dependency).
  4. gRPC calls have timeout + circuit breaker.
  5. Kafka events follow CloudEvents v1.0 envelope.
  6. No cross-service database access.
  7. Docker Compose stack starts cleanly with the change.
  8. Test coverage meets threshold (target: 80% per service).
- PRs that touch authentication, authorization, payment, or escrow logic MUST be
  reviewed by a second developer.
- Database migrations MUST be reviewed for reversibility before merging.
- The PR checklist in `docs/architecture/Implementation Governance.md` is
  binding.

### PR Checklist with Severity Levels

| # | Check | Severity |
|---|-------|----------|
| 1 | No shared database access | P0 — Block merge |
| 2 | Cross-service reads use gRPC/projection only (not REST, not direct DB) | P0 — Block merge |
| 3 | gRPC calls have timeout (5s/10s/10s), circuit breaker, graceful degradation | P0 — Block merge |
| 4 | Batch gRPC methods for all list-context lookups (no N+1) | P0 — Block merge |
| 5 | New Kafka events follow CloudEvents v1.0 envelope | P1 — Fix within sprint |
| 6 | Kafka consumers are idempotent (upsert, not insert) | P1 — Fix before deploy |
| 7 | Projection tables updated only by Kafka consumers | P0 — Block merge |
| 8 | Financial data never cached or projected | P0 — Block merge |
| 9 | Pydantic models on every endpoint (request, response, path/query params) | P0 — Block merge |
| 10 | Proto files backward-compatible (additive only) | P0 — Block merge |

### Boundary Violation Severity

| Severity                | Example                                            | Action                            |
|-------------------------|----------------------------------------------------|-----------------------------------|
| **P0 — Block merge**   | Service connecting to another service's DB          | Must fix before merge             |
| **P0 — Block merge**   | gRPC call without timeout or circuit breaker        | Must fix before merge             |
| **P0 — Block merge**   | Financial data stored in projection/cache           | Must fix before merge             |
| **P0 — Block merge**   | N+1 gRPC calls (no batch endpoint)                  | Must fix before merge             |
| **P1 — Fix in sprint** | Missing CloudEvents field in Kafka event            | Merge allowed, tracked as debt    |
| **P1 — Fix in sprint** | Kafka consumer not idempotent                       | Merge allowed, fix before deploy  |
| **P2 — Track**         | gRPC call where projection would suffice            | Add to backlog                    |

### CI Enforcement

| Tool                        | What It Catches                                      |
|-----------------------------|------------------------------------------------------|
| `buf lint` + `buf breaking` | Proto style violations and backward-incompatible changes |
| Custom DB connection audit  | Service importing another service's DB connection     |
| `pytest --cov`              | Coverage below 80% threshold                         |
| Contract test suite         | gRPC proto compatibility between producer/consumer    |
| Kafka schema registry check | Event schema changes that break existing consumers    |

### Weekly Architecture Review Gate

Triggers requiring Architecture Board approval:

| Trigger                       | What Must Be Reviewed                                  |
|-------------------------------|--------------------------------------------------------|
| New gRPC endpoint             | Proto definition, batch variant, timeout, circuit breaker, idempotency key, update api-contracts.md |
| New Kafka event type          | CloudEvents envelope, topic assignment, all consumer registrations, DLQ handling, schema in kafka-event-schemas.md |
| New local projection table    | Kafka consumer feed, upsert logic, fields are display-only (no financial data), staleness acceptable |
| New cross-service dependency  | Confirm allowed direction per dependency graph. Reject if creates sync cycle. |
| Database migration            | Targets only the service's own DB. Rejected if affects another service's schema. |
| New denormalized field        | Via CloudEvents — source service's event carries the computed value. |

### Monthly Service Health Audit

- Zero shared database connections across all services.
- gRPC contract compatibility — `buf breaking` against last released proto.
- Projection staleness — all projection tables `updated_at` within < 5 minutes.
- Circuit breaker coverage — every gRPC client has circuit breaker with recorded
  metrics.
- Kafka consumer lag — all consumer groups within threshold (< 1000 messages).
- Independent deployability — each service's CI can build, test, deploy solo.
- **Metric:** cross-service gRPC call count per request (track trend for
  composition efficiency).

## Governance

This constitution supersedes all informal practices for the Marketplace project.
Amendments require:

1. A documented rationale (inline comment or linked ADR).
2. A version bump following semantic versioning:
   - **MAJOR** — principle removals, redefinitions, or breaking workflow changes.
   - **MINOR** — new principles or materially expanded guidance.
   - **PATCH** — clarifications, wording fixes, non-semantic refinements.
3. All specs, plans, and implementation artifacts MUST be verified against this
   constitution before development begins.
4. Complexity MUST be justified — if a proposed implementation cannot be explained
   in plain language, simplify it first.
5. Use `marketplace-constitution.md` at the project root as the authoritative
   source; this Spec Kit copy is kept in sync.

**Version**: 2.0.0 | **Ratified**: 2026-03-17 | **Last Amended**: 2026-03-18
