# CMS Platform --- Feature-Based System Design Blueprint

## 1. Document Purpose

This document defines the complete system design blueprint structured
around the core features of the CMS Platform. Each feature is decomposed
into mandatory scope/architecture sections and explicit cross-cutting
controls. Coverage for the dimensions below is provided either directly
inside each feature section or by referenced shared sections:

-   Functional scope
-   Architectural boundaries
-   Data flow
-   Security considerations
-   Scalability implications
-   Failure handling strategy
-   Future extensibility

This blueprint aligns with production-grade SaaS and headless
architecture standards.

Canonical architecture decisions are maintained in
`CMS_Architecture_Decision_Matrix.md`.

------------------------------------------------------------------------

# 2. Core Feature Matrix

The platform consists of the following primary feature domains:

1.  Multi-Tenancy & Project Isolation
2.  Authentication & Role-Based Access Control
3.  Structured Content Management
4.  Rich Text Editor Engine
5.  Visual Page Builder Engine
6.  Media Management System
7.  Public Content Delivery API
8.  Versioning & Publishing Workflow
9.  API Key & Access Governance
10. Subscription & Plan Enforcement
11. Usage Metering & Quotas
12. Feature Flags & Configuration
13. Observability & Audit Logging
14. Security & Rate Limiting
15. SDK & Developer Experience

Each section below describes the complete system design for that
feature.

Cross-cutting inheritance rules:

-   Failure handling defaults are centralized in Sections 12, 15, 16, and 18
    unless a feature defines stricter behavior
-   Extensibility baselines are defined by modular service boundaries,
    feature flags, and API versioning constraints in feature sections

------------------------------------------------------------------------

# 3. Multi-Tenancy & Project Isolation

## Functional Scope

-   Support multiple isolated projects/sites
-   Independent content domains
-   Isolated storage paths
-   Scoped API keys

## Architecture

Isolation enforced at:

-   API Layer (Supabase JWT validation + tenant resolution middleware)
-   Service Layer (project-aware services)
-   Database Layer (tenant identifiers + PostgreSQL RLS policies)
-   Storage Layer (tenant-scoped asset namespaces)

## Data Flow

Incoming Request → JWT Validation → Tenant Resolution → Scoped Service
Execution → Tenant-Constrained Persistence

## Security

-   No cross-tenant query execution
-   Strict scoping in every domain service
-   RLS as the final enforcement boundary for tenant isolation
-   Request-scoped DB context with transaction-bound claim mapping to
    prevent pooled connection context leakage

## Scalability

-   Horizontal scaling supported
-   Tenant partitioning strategy for future sharding

------------------------------------------------------------------------

# 4. Authentication & Role-Based Access Control

## Functional Scope

-   User login & session management
-   Role-based permissions (Owner, Admin, Editor, Viewer)

## Architecture

-   Supabase Auth issues JWTs
-   Express middleware validates JWTs and resolves tenant/user claims
-   Short-lived access JWTs (<= 15 minutes) with refresh rotation
-   Revocation guard checks token `iat` against tenant/user
    `revoke_before` timestamps
-   Clock skew tolerance for `iat`/`nbf` validation: +/- 60 seconds
-   Revocation propagation target: <= 60 seconds to enforcement path
-   On revocation-cache miss, fallback to authoritative store before
    allowing mutating/admin operations
-   If revocation dependencies are unavailable, mutating/admin operations
    fail closed
-   Authenticated read endpoints may proceed only when revocation cache
    state is fresh (<= 60 seconds) or authoritative validation succeeds
-   If both cache and authoritative revocation dependencies are
    unavailable, authenticated read endpoints fail closed with
    `503 Service Unavailable`
-   Public API-key delivery endpoints are not blocked by user-token
    revocation dependency outages because they do not rely on user JWT
    revocation checks
-   Permission checks enforced at service layer
-   Role matrix defines action permissions
-   PostgreSQL RLS enforces final read/write boundaries

## Security

-   Server-side permission enforcement only
-   Fail-closed access when JWT or tenant context is missing
-   API route-level guards
-   Audit logging on privilege escalation

------------------------------------------------------------------------

# 5. Structured Content Management

## Functional Scope

-   Create, edit, delete content
-   SEO metadata management
-   Tag/category relationships

## Architecture

Content Model Components:

-   Document Root
-   Block Nodes
-   Inline Nodes
-   Metadata
-   Relationships

NormalizedDocument: { version, blocks\[\], metadata, relations }

## Scalability

-   Optimized read path
-   Pre-normalized response payloads

------------------------------------------------------------------------

# 6. Rich Text Editor Engine

## Functional Scope

-   Structured text editing with Tiptap (headless)
-   Custom nodes (image, embed, callout)
-   Slash command support
-   Structured JSON export for persistence

## Architecture

Tiptap Editor State → Structured JSON Output → Normalization Layer →
Persisted CMS Document (PostgreSQL)

Editor state must remain isolated from global UI state.

## Risk Areas

-   Re-render storms
-   Version lock-in

Mitigation:
-   Dedicated state store
-   Editor-version abstraction layer

------------------------------------------------------------------------

# 7. Visual Page Builder Engine

## Functional Scope

-   Drag-and-drop layout system
-   Section & block hierarchy
-   Responsive structure

## Architecture

Separation of concerns:

Layout JSON Content JSON Theme Configuration Component Registry

Block registration model:

registerBlock({ type, schema, renderer })

## Performance Considerations

-   Lazy rendering
-   Component memoization
-   Hydration optimization

------------------------------------------------------------------------

# 8. Media Management System

## Functional Scope

-   Upload media
-   Organize assets
-   Store metadata

## Architecture

Offloaded Processing Model (Cloudinary/UploadThing):

1.  Request upload signature/token from backend
2.  Direct client upload to Cloudinary/UploadThing CDN
3.  Provider-side resizing/compression/transformation on delivery
4.  Metadata persistence in PostgreSQL

No local filesystem storage and no raw media transformation workload on
the Node.js backend.

## Scalability

-   CDN-compatible storage
-   Near-zero backend CPU cost for image optimization

------------------------------------------------------------------------

# 9. Public Content Delivery API

## Functional Scope

-   Fetch by slug
-   Fetch by type
-   Filtered queries
-   Full-text discovery using PostgreSQL native search

## Architecture

-   Stateless
-   Cache-friendly
-   Slug-index optimized
-   No runtime heavy joins
-   PostgreSQL FTS (`tsvector` + `GIN`) for tenant-scoped search
-   Lifecycle access policy evaluated at API key boundary
-   Trial, Active, and Grace tenants are allowed within plan/trial
    limits; Suspended/Archived/Deleted tenants are denied
-   Lifecycle decisions are served from a data-plane entitlement snapshot
    (replicated table/cache), not live control-plane calls
-   Entitlement freshness target <= 60 seconds replication lag; state
    older than 120 seconds is considered stale
-   Lifecycle event sync uses at-least-once delivery with per-tenant
    monotonic version ordering and idempotent upserts
-   Entitlement reconciliation runs every 5 minutes against
    authoritative control-plane state

## Caching Layers

-   CDN Edge Cache
-   Application Cache
-   Database query optimization
-   Tenant-tag cache purge on lifecycle transitions (suspend/archive/delete)
-   300-second max TTL for lifecycle-sensitive delivery responses
-   If purge fails/backlogs, bypass stale cache and force origin
    revalidation until purge confirmation
-   If entitlement state is unavailable or stale beyond 120 seconds,
    lifecycle-sensitive delivery responses fail closed

------------------------------------------------------------------------

# 10. Versioning & Publishing Workflow

## Functional Scope

-   Draft state
-   Published state
-   Scheduled publish
-   Rollback support

## Architecture

Immutable revision model:

ContentRevision { contentSnapshot, timestamp, author }

## Safety

-   Publish action must create new revision
-   Rollback restores snapshot

------------------------------------------------------------------------

# 11. API Key & Access Governance

## Functional Scope

-   Project-level API keys
-   Read-only vs admin keys

## Architecture

-   Key validation middleware
-   Scoped rate limits
-   Key rotation support

------------------------------------------------------------------------

# 12. Subscription & Plan Enforcement

## Functional Scope

-   Plan limits
-   Feature access control
-   Usage caps

## Enforcement Points

-   Middleware real-time quota checks (low-latency counters)
-   Domain service validation (hard limits on write operations)
-   Usage metering service (asynchronous billing and analytics)
-   Authoritative quota ledger in PostgreSQL for final allow/deny checks
-   Cache fallback to ledger on miss/staleness
-   API request limits apply to both read and write endpoints
-   Fail-closed mutating requests when both cache and ledger are
    unavailable
-   Mutating requests require `Idempotency-Key` for safe retries
-   When quota dependencies are unavailable, mutating requests return
    `503 Service Unavailable`
-   Read-only delivery endpoints may use emergency tenant-scoped
    read budget only when last-known-good counters are <= 15 minutes old
-   Emergency read budget seed per outage window:
    `min(max(100, ceil(1% of tenant daily read quota)), 5000)` requests
-   If no valid last-known-good counter snapshot exists, read endpoints
    fail closed with `503 Service Unavailable` (no emergency budget)
-   Budget exhaustion returns `429 Too Many Requests` with
    `Retry-After: 60`
-   Emergency-budget read requests emit provisional usage events with
    outage window IDs for deterministic post-recovery reconciliation
-   Emergency budget resets to zero after quota dependency recovery and
    successful ledger backfill completion
-   Retries must reuse the same `Idempotency-Key`
-   Idempotency-key deduplication window: minimum 24 hours

Request-time allow/deny decisions must not depend on eventual-consistent
billing aggregates.

------------------------------------------------------------------------

# 13. Usage Metering & Quotas

## Metrics Tracked

-   API calls
-   Storage usage
-   Content count
-   Bandwidth

## Architecture

Request → Quota Check (Cache → Ledger Fallback) → Response + Usage Event
→ Quota counter updates + Aggregation service → Billing engine

Metering must be decoupled from content tables and is not the sole
source for real-time request gating.

------------------------------------------------------------------------

# 14. Feature Flags & Configuration

## Functional Scope

-   Plan-based features
-   Beta toggles
-   Tenant overrides

## Architecture

-   Server-side evaluation
-   Cached flag resolution
-   Feature matrix enforcement

------------------------------------------------------------------------

# 15. Observability & Audit Logging

## Logging Requirements

-   API request logs
-   Error logs
-   Security events
-   Content modification logs

## Monitoring Requirements

-   Latency tracking
-   Error rate thresholds
-   Storage growth monitoring
-   Tenant performance metrics
-   Availability SLO >= 99.5% monthly
-   Public delivery p95 <= 250ms (CDN hit) / <= 700ms (origin miss)
-   Authenticated write API p95 <= 800ms
-   5xx error rate < 1.0% over rolling 5-minute windows
-   Entitlement replication SLO: 99% of lifecycle updates applied within
    60 seconds; no responses served with entitlement older than 120 seconds
-   Revocation enforcement SLO: 99.9% of revocations enforced within 60
    seconds across cache + authoritative fallback paths
-   Quota fallback SLO: cache->ledger fallback rate < 1% in steady state
-   Measure entitlement snapshot lag/stale reject count, revocation
    dependency availability, and emergency-budget activation rate
-   SLI windows: 5-minute error windows, 15-minute latency windows,
    monthly availability windows
-   Page on-call when latency/error SLOs breach for two consecutive
    windows
-   SLI systems of record: availability from gateway uptime + synthetic
    checks, delivery latency from CDN telemetry/origin traces, write
    latency from APM traces, 5xx from gateway + app error metrics,
    entitlement lag from event bus + snapshot age metrics, revocation
    lag from auth decision logs + pipeline metrics, quota fallback from
    quota middleware + reconciliation telemetry

------------------------------------------------------------------------

# 16. Security & Rate Limiting

## Security Controls

-   Input validation
-   Role-based access
-   Rate limiting
-   API key rotation
-   Provider-issued upload signature expiration

## Rate Limiting Strategy

-   Per-tenant quotas
-   Burst control
-   IP throttling

------------------------------------------------------------------------

# 17. SDK & Developer Experience

## Functional Scope

-   Typed client SDK
-   Lightweight integration
-   API abstraction

## Architecture

cms.init({ apiKey }) cms.pages.getBySlug() cms.posts.getAll()

SDK must include: - Caching - Edge compatibility - Minimal bundle
footprint

------------------------------------------------------------------------

# 18. System-Wide Non-Functional Requirements

-   Stateless services
-   Horizontal scalability
-   Clear service boundaries
-   Zero cross-tenant leakage
-   Immutable content revisions
-   Cloud-native deployment compatibility
-   Compliant tenant deletion with anonymized/tombstoned immutable audit
    traces
-   PITR-enabled PostgreSQL backup strategy to sustain RPO <= 1h
-   Recovery objectives: RTO <= 4h, RPO <= 1h (primary metadata),
    <= 24h (derived analytics/metering)
-   Restore validation cadence: quarterly full restore drills + monthly
    table-level restore spot checks with remediation tracking
-   Retention baseline:
    tenant content/metadata hard delete <= 30 days after confirmed
    deletion unless legal hold applies; immutable audit trails 13 months
    with subject anonymization on erasure; security logs 12 months
    (90 days hot + cold archive); derived metering aggregates 24 months;
    billing/invoice artifacts retained per legal/tax requirements
    (typically up to 7 years)

------------------------------------------------------------------------

# 19. Architectural Maturity Level

This feature-based blueprint demonstrates:

-   Modular system design
-   Layer isolation
-   SaaS governance readiness
-   Scalable API strategy
-   Structured content modeling
-   Operational resilience planning

It represents enterprise-ready system engineering.

------------------------------------------------------------------------

End of Feature-Based System Design Blueprint
