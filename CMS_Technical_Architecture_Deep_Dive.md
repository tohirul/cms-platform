# CMS Platform --- Technical Architecture Deep Dive

## 1. System Context

The CMS Platform is a multi-tenant, headless content infrastructure
system designed for structured content modeling, API-first delivery, and
extensible rendering across multiple client applications.

This document provides a deep architectural breakdown of system layers,
internal boundaries, execution flow, performance considerations, and
long-term scalability planning.

Canonical architecture decisions are maintained in
`CMS_Architecture_Decision_Matrix.md`.

---

# 2. Layered Architecture Model

The system follows a strict layered architecture:

Presentation Layer (Admin UI) ↓ Application Layer (Backend Core API) ↓
Domain Layer (Content & Business Logic) ↓ Persistence Layer
(PostgreSQL/Supabase + Drizzle + RLS) ↓ Media Layer
(Cloudinary/UploadThing CDN + metadata references) ↓ Delivery Layer
(Read-Optimized Public API)

Each layer has clearly defined responsibilities to prevent cross-layer
coupling.

---

# 3. Admin UI Architecture

## 3.1 Functional Modules

The Admin Dashboard must be modularized into:

- Authentication Module
- Project Management Module
- Content Authoring Module
- Page Builder Module
- Media Management Module
- Settings & Configuration Module

## 3.2 State Management Strategy

State must be segmented:

- Editor State (isolated store)
- Page Builder Layout State (separate store)
- Global UI State (lightweight store)
- Network Cache State (request layer)

Avoid global React Context for deep editor state.

---

# 4. Backend Core Architecture

## 4.1 API Segmentation

Separate APIs by concern:

- Auth API
- Project API
- Content API
- Media API
- Public Delivery API

The public API must remain read-only and stateless.

## 4.2 Authentication & Tenant Scoping Flow

Client (Next.js) → Supabase Auth (JWT Issuance) → Express API (Bearer
Token) → JWT Validation Middleware → Tenant Resolution → Authorization
Check → Validation Layer → Domain Service → Persistence Layer →
Response Serializer

The middleware validates Supabase-issued JWTs before domain execution.
Every request must pass through tenant scoping logic.

Security hardening contract:

- Short-lived access tokens (<= 15 minutes) with refresh rotation
- Revocation guard compares token `iat` against tenant/user
  `revoke_before` timestamps
- Clock skew tolerance for `iat`/`nbf` validation: +/- 60 seconds
- Revocation propagation target: <= 60 seconds to enforcement path
- On revocation-cache miss, middleware must fallback to authoritative
  store before allowing mutating/admin operations
- If revocation dependencies are unavailable, mutating/admin operations
  fail closed
- Authenticated read endpoints may proceed only when revocation cache
  state is fresh (<= 60 seconds) or authoritative validation succeeds
- If both cache and authoritative revocation dependencies are
  unavailable, authenticated read endpoints fail closed with
  `503 Service Unavailable`
- Public API-key delivery endpoints are not blocked by user-token
  revocation dependency outages because they do not rely on user JWT
  revocation checks

## 4.3 Database Access & RLS Enforcement

The Express service layer forwards request identity context to
PostgreSQL through Drizzle-backed data access so Row Level Security
(RLS) policies are evaluated per request.

Enforcement model:

- JWT claims are propagated as request-scoped database context.
- RLS policies enforce tenant/user boundaries at the data layer.
- Application-layer checks in Express provide defense-in-depth.
- Request-scoped transaction context sets `app.tenant_id`,
  `app.user_id`, and `app.role` before query execution.
- Transaction boundaries clear context to prevent pooled-connection
  context leakage.
- Repository operations without scoped context are rejected.

This model prevents cross-tenant access even if an application query is
mis-scoped.

---

# 5. Multi-Tenancy Isolation Strategy

Tenant isolation must be enforced at:

1.  API layer (scoped tokens)
2.  Service layer (project-aware queries)
3.  Database layer (project identifiers)
4.  Storage layer (tenant-scoped Cloudinary/UploadThing namespaces and
    provider-issued upload signatures)

No cross-tenant data access should be possible at any level.

---

# 6. Content Modeling Strategy

## 6.1 Structured Document Model

Content consists of:

- Document Root
- Block Nodes
- Inline Nodes
- Metadata (SEO, timestamps, status)
- Relationships (author, tags, categories)

The system must avoid storing raw HTML.

## 6.2 Content Normalization

Editor output must be normalized into:

NormalizedDocument { version blocks\[\] metadata relationships }

This prevents editor-version coupling.

---

# 7. Page Builder Engine Architecture

## 7.1 Structural Separation

Layout JSON defines structure only.

Content JSON defines textual or embedded content.

Theme configuration defines styling tokens.

Component Registry maps block types to rendering components.

## 7.2 Block Registration Model

Blocks must be registered through a registry pattern, allowing
extensibility without modifying core engine logic.

---

# 8. Media Handling Architecture

## 8.1 Cloudinary/UploadThing Direct Upload Flow

1.  Admin requests upload authorization from the Express API.
2.  Backend returns provider-specific short-lived upload signature/token.
3.  Client uploads directly to Cloudinary/UploadThing CDN.
4.  Cloudinary/UploadThing performs on-the-fly
    resizing/compression/format optimization.
5.  Backend persists asset metadata and provider asset identifiers in
    PostgreSQL.

This removes backend file buffering and offloads media processing CPU
from the Node.js/Express runtime.

---

# 9. Public Delivery API Architecture

## 9.1 Read Optimization

The public API must:

- Support slug-based retrieval
- Return pre-normalized content
- Avoid runtime joins
- Support ETag and cache headers
- Enforce tenant lifecycle policy at API key boundary
- Allow Trial/Active/Grace tenants within plan and trial limits
- Deny Suspended/Archived/Deleted tenants
- Resolve lifecycle decisions from a data-plane entitlement snapshot
  (not live billing-provider calls)
- Target entitlement freshness <= 60 seconds replication lag
- Process lifecycle events at-least-once with per-tenant monotonic
  version ordering and idempotent upserts
- Treat entitlement state older than 120 seconds as stale and fail
  closed for lifecycle-sensitive delivery requests

## 9.2 Search Strategy

Search uses PostgreSQL native full-text search for tenant-scoped,
cost-efficient discovery:

- `tsvector` indexed searchable fields
- `GIN` indexes for low-latency lookup
- Tenant-scoped `tsquery` execution under the same RLS boundaries

## 9.3 Caching Strategy

Layered caching:

- CDN edge caching (External Provider or Client-Side Framework)
- Application-level HTTP caching (Control-Cache headers)
- Database query optimization
- Tenant-tag cache purge on lifecycle transitions
  (suspend/archive/delete) - _Requires external CDN integration_
- Maximum TTL of 300 seconds for lifecycle-sensitive delivery responses
- If purge fails or backlogs grow, bypass stale cache and force origin
  revalidation until purge confirmation
- Entitlement reconciliation every 5 minutes against authoritative
  control-plane state

---

# 10. Versioning and Draft Workflow

The architecture must support:

- Draft state
- Published state
- Scheduled publishing
- Immutable content versions
- Rollback capability

Versioning should be immutable to avoid historical corruption.

---

# 11. Scalability Architecture

## 11.1 Horizontal Scaling

Because APIs are stateless:

- Multiple instances can scale automatically
- Database pooling is mandatory
- Storage remains externalized

## 11.2 Performance Bottlenecks

Key risks:

- Deep JSON render trees
- Page builder hydration cost
- Free-tier instance cold starts
- Database connection exhaustion

Mitigations include caching and query optimization.

## 11.3 Cold Start Mitigation (Render Free Tier)

To reduce free-tier sleep impact, the backend exposes a lightweight
`GET /health` endpoint.

Operational pattern:

- A cron job periodically pings `/health`.
- The endpoint returns fast liveness/uptime status.
- This keeps the Render instance warm for demo traffic patterns.

---

# 12. Security Model

Security must include:

- Role-Based Access Control
- API key scoping
- Rate limiting
- Input validation
- Content sanitization
- Provider-issued upload signature expiration

---

# 13. Observability & Monitoring

System must support:

- Request logging
- Error tracking
- Performance metrics
- API latency tracking
- Storage usage monitoring
- Entitlement replication lag and stale-state reject monitoring
- Revocation propagation lag and dependency availability monitoring
- Quota fallback and emergency-budget activation monitoring

Service objectives:

- API availability SLO: >= 99.5% monthly
- Public delivery latency SLO: p95 <= 250ms (CDN hit), p95 <= 700ms
  (origin miss)
- Authenticated write API latency SLO: p95 <= 800ms
- 5xx error-rate SLO: < 1.0% over rolling 5-minute windows
- Entitlement replication SLO: 99% of lifecycle updates applied within
  60 seconds
- Revocation enforcement SLO: 99.9% of revocations enforced within 60
  seconds across cache + authoritative fallback paths
- Quota fallback SLO: cache->ledger fallback rate < 1% in steady state
- SLI windows: 5-minute error windows, 15-minute latency windows, and
  monthly availability windows
- Alert trigger baseline: page on-call when latency/error SLOs breach
  for two consecutive windows

SLI systems of record:

- Availability and 5xx: gateway telemetry + synthetic checks
- Latency: CDN telemetry + origin API traces/APM
- Entitlement lag: event pipeline lag + snapshot age metrics
- Revocation lag: auth middleware decision logs + revocation pipeline
  metrics
- Quota fallback: quota middleware counters + reconciliation telemetry

Monitoring is critical before scaling to production.

---

# 14. Failure Handling Strategy

The system must gracefully handle:

- Database downtime
- Storage failures
- Partial content corruption
- Invalid editor state

Fallback mechanisms must prevent total application crash.

---

# 15. Future Architecture Extensions

The system is designed to extend into:

- Advanced billing models (tiered overage pricing, annual commitments)
- Webhook system
- Background job processing
- Plugin marketplace
- Real-time collaboration
- AI-assisted content tools

The layered architecture supports these evolutions.

---

# 16. Engineering Maturity Level

This architecture demonstrates:

- Domain-driven separation
- Stateless API design
- Multi-tenant isolation
- Structured content modeling
- Scalable stateless deployment alignment
- Extensible block system design

It represents production-grade systems engineering.

---

End of Technical Architecture Deep Dive
