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
- **Mandatory Transaction Wrapper**: Access must use a custom repository pattern or Drizzle ORM middleware to strictly enforce `app.tenant_id` session setting.
- The wrapper executes `set_config('app.tenant_id', ...)` within the transaction before any query.
- Raw queries or direct DB access bypassing this wrapper are strictly prohibited to prevent developer error.
- Transaction boundaries clear context to prevent pooled-connection context leakage.

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

**Resolution Note**: CMS-Feature.md Phase 2 suggests using Next.js `<Image />`
component for on-the-fly optimization. This architecture uses
Cloudinary/UploadThing instead because:
- Transformations happen at CDN edge (closer to user, faster)
- Zero origin CPU overhead for image processing
- Built-in format optimization (WebP/AVIF) without origin work
- Superior for high-traffic CMS workloads

## 8.2 In-Browser Image Editor (Phase 12)

- Canvas-based frontend cropping/rotation using react-image-crop
- Backend endpoint to process transformations via Sharp
- "Restore Original" feature storing reference to unmodified file
- CDN cache invalidation on edits

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

# 16. Phase 5: Hooks System (Extensibility Core)

**Status**: PLANNED (Critical for WordPress feature parity)

## 16.1 Event Hooks (WordPress add_action equivalent)

```typescript
// HookRegistry pattern
interface HookRegistry {
  doAction(action: string, payload: any): Promise<void>;
  addAction(action: string, callback: HookCallback): void;
}
```

Core actions to implement:
- `onContentCreate` - When new content is created
- `onContentPublish` - When content is published
- `onContentUpdate` - When content is modified
- `onContentDelete` - When content is deleted
- `onUserRegister` - When new user signs up
- `onUserLogin` - When user authenticates
- `onFormSubmit` - When form is submitted

## 16.2 Filters (WordPress add_filter equivalent)

```typescript
interface FilterRegistry {
  applyFilters(filter: string, value: any, context: HookContext): Promise<any>;
  addFilter(filter: string, callback: FilterCallback): void;
}
```

Core filters:
- `content_output` - Modify rendered content
- `seo_metadata` - Modify SEO tags before rendering
- `email_template` - Modify email before sending
- `api_response` - Modify API response payload

## 16.3 Modular Plugin Architecture

```
/system-modules/        # Immutable boot modules (Phase 28)
/plugins/                # User-installable plugins (auto-registered)
/modules/                # Core feature modules
```

Each module registers hooks in its entry point. The HookRegistry executes all registered callbacks in priority order.

---

# 17. Phase 10: Database-Backed Job Queue

**Status**: PLANNED (WP-Cron alternative)

## 17.1 Architecture

- `job_queue` table: id, payload (JSONB), status, attempts, scheduled_at, started_at, completed_at
- Node.js worker process polls with `FOR UPDATE SKIP LOCKED`
- Admin dashboard for job status monitoring
- Used for: scheduled publishing, webhook dispatch, batch emails, report generation

## 17.2 Concurrent Worker Safety

```sql
UPDATE job_queue
SET status = 'running', started_at = NOW()
WHERE id = (
  SELECT id FROM job_queue
  WHERE status = 'pending' AND scheduled_at <= NOW()
  ORDER BY scheduled_at ASC
  LIMIT 1
  FOR UPDATE SKIP LOCKED
)
RETURNING *;
```

---

# 18. Phase 11: Content Syndication & i18n

## 18.1 RSS/Atom Feed Generation

- `/feed.xml` route handler
- Query published content_nodes
- Map to RSS 2.0 XML structure
- Cached with revalidate timers

## 18.2 Multi-Language (i18n)

**Resolution Note**: CMS-Feature.md Phase 11 specifies storing translations
in single row with locale keys in JSONB. This architecture implements:

- Single canonical content_node per locale key in JSONB
- Next.js App Router `[lang]` dynamic segment
- Content API filters by `locale` parameter

---

# 19. Phase 24: Pluggable Email Engine

**Status**: PLANNED

## 19.1 Architecture

- `cms.sendEmail()` - Central email utility (not hardcoded nodemailer)
- Adapter pattern for provider switching (SMTP, AWS SES, Resend)
- React Email for templating
- Hook integration: modules can intercept email payload

---

# 20. Phase 27: Expiring Key-Value Store (Transients API)

**Status**: PLANNED (Alternative to WordPress Transients)

## 20.1 Architecture

- `transients` table: key (PK), value (JSONB), expiration_time
- Helper functions:
  - `setTransient(key, value, ttlSeconds)` - Insert/update with expiry
  - `getTransient(key)` - Return value if not expired, else null
  - `deleteTransient(key)` - Manual invalidation
- Background cron job cleans expired rows (Phase 10 job queue)

## 20.2 Use Cases

- Cache expensive API responses (e.g., GitHub repo stats)
- Store computed aggregates
- Rate limit token buckets

---

# 21. Phase 28: Immutable Boot Modules (mu-plugins)

**Status**: PLANNED

## 21.1 Architecture

- `/system-modules/` directory in Node.js backend
- Auto-loaded before standard module registry
- Used for: security enforcement, network-wide policies, required logging
- Cannot be disabled by tenant admins

---

# 22. Engineering Maturity Level

This architecture demonstrates:

- Domain-driven separation
- Stateless API design
- Multi-tenant isolation
- Structured content modeling
- Scalable stateless deployment alignment
- Extensible block system design
- Hook-based plugin architecture

It represents production-grade systems engineering.

---

End of Technical Architecture Deep Dive
