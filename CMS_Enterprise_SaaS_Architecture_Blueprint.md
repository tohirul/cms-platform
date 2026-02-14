# CMS Platform --- Enterprise SaaS Architecture Blueprint

## Research-Driven System Design & Governance Documentation

------------------------------------------------------------------------

# 1. Executive Context

This document defines the complete SaaS transformation architecture of
the CMS Platform, engineered as a production-grade, multi-tenant,
subscription-based content infrastructure system.

The architecture aligns with modern SaaS principles including:

-   Control Plane / Data Plane separation
-   Multi-layer tenant isolation
-   Lifecycle-driven governance
-   Usage-based monetization
-   Stateless service design
-   Horizontal scalability
-   Observability-first operations
-   Enterprise upgrade readiness

This blueprint is structured to serve as a foundational systems design
document suitable for technical leadership, investors, and engineering
teams.

Canonical architecture decisions are maintained in
`CMS_Architecture_Decision_Matrix.md`.

------------------------------------------------------------------------

# 2. SaaS Macro Architecture

## 2.1 Logical Plane Separation

The system is divided into two macro layers:

### Control Plane (SaaS Governance Layer)

Responsible for:

-   Tenant lifecycle management
-   Subscription management
-   Plan enforcement
-   Billing integration
-   Feature flag governance
-   Usage metering
-   SaaS administrative operations
-   Global analytics and health monitoring

### Data Plane (Content Infrastructure Layer)

Responsible for:

-   Content storage
-   Media storage
-   Public content delivery API
-   Tenant-isolated application APIs
-   Content versioning
-   Page builder persistence

Separation minimizes coupling between billing/lifecycle logic and content
delivery performance. Delivery authorization does not depend on live
billing-provider calls and uses explicit fail-closed policies when
entitlement state is stale or unavailable.

------------------------------------------------------------------------

# 3. Tenant Lifecycle Architecture

## 3.1 Lifecycle States

Every tenant follows a deterministic state machine:

-   Trial
-   Active (Paid)
-   Grace Period
-   Suspended
-   Archived
-   Deleted

## 3.2 Lifecycle Enforcement Points

Lifecycle validation must occur at:

-   Authentication middleware
-   API request entrypoint
-   Background job triggers
-   Media upload authorization

No API route should execute business logic without validating tenant
state.

## 3.3 Delivery Access Contract

Public delivery access is lifecycle-aware, but evaluated only at the API
key/auth boundary.

Enforcement policy:

-   Trial, Active, and Grace Period tenants can access delivery APIs
    within plan/trial limits.
-   Suspended, Archived, and Deleted tenants are denied delivery access.
-   Delivery requests must not depend on live billing-provider lookups.
-   Delivery authorization reads tenant lifecycle state from a
    data-plane entitlement snapshot (replicated table/cache) fed by
    control-plane events.
-   Entitlement freshness target is <= 60 seconds replication lag; state
    older than 120 seconds is considered stale.
-   Lifecycle events are processed at-least-once with per-tenant
    monotonic version ordering and idempotent upserts.
-   Reconciliation jobs run every 5 minutes against authoritative
    control-plane state; unresolved drift pages on-call.
-   If entitlement state is unavailable or stale beyond 120 seconds,
    lifecycle-sensitive delivery requests fail closed.

## 3.4 State Transition Governance

Transitions must be triggered only by:

-   Billing webhooks
-   Admin override actions
-   Automated lifecycle jobs
-   Usage limit violations

Manual database edits must not change lifecycle state.

------------------------------------------------------------------------

# 4. Multi-Tenant Isolation Strategy

Isolation is enforced across four layers, with PostgreSQL Row Level
Security (RLS) as the primary persistence boundary and Express
application validation as defense-in-depth.

## 4.1 API Layer

-   Supabase JWT validation middleware in Node.js/Express
-   Tenant resolution from validated token claims
-   Scoped API tokens
-   Strict header validation
-   Short-lived access tokens (<= 15 minutes) with refresh rotation
-   Revocation guard checks token `iat` against tenant/user
    `revoke_before` timestamps (cached with short TTL)
-   Clock skew tolerance for `iat`/`nbf` validation: +/- 60 seconds
-   Revocation propagation target: <= 60 seconds from control action to
    enforcement path
-   On revocation-cache miss, middleware must fallback to authoritative
    store before allowing mutating/admin operations
-   If revocation dependencies are unavailable, mutating/admin operations
    fail closed
-   Authenticated read endpoints may proceed only when revocation cache
    state is fresh (<= 60 seconds) or authoritative validation succeeds
-   If both cache and authoritative revocation dependencies are
    unavailable, authenticated read endpoints fail closed with
    `503 Service Unavailable`
-   Public API-key delivery endpoints are not blocked by user-token
    revocation dependency outages because they do not use user JWT
    revocation checks

## 4.2 Service Layer

-   Project-aware domain services
-   Mandatory tenant parameter in service contracts
-   Explicit authorization checks before persistence operations

## 4.3 Persistence Layer

-   Tenant identifiers in every content table
-   Mandatory Row-Level Security (RLS) policies on tenant-owned tables
-   Request-scoped identity context forwarded from Express to PostgreSQL
-   JWT claims mapped to database session context per request
-   Request-scoped transaction sets `app.tenant_id`, `app.user_id`, and
    `app.role` before any query execution
-   Transaction boundary clears session context to prevent pooled
    connection context bleed
-   Repository operations outside scoped context are rejected
-   Fail-closed RLS behavior when tenant/user context is missing
-   Database-enforced prevention of cross-tenant reads/writes

## 4.4 Storage Layer

-   Tenant-prefixed asset namespaces
-   Provider-issued upload signatures (Cloudinary/UploadThing)
-   Storage usage tracking per tenant

No cross-tenant leakage is permissible even under application
misconfiguration because the database enforces tenant boundaries.

------------------------------------------------------------------------

# 5. Subscription & Billing Architecture

## 5.1 Billing Integration Model

The SaaS must integrate with an external billing provider capable of:

-   Recurring subscriptions
-   Usage-based metering
-   Webhook event dispatch
-   Invoice lifecycle tracking
-   Failed payment automation

Billing events must update the Control Plane state machine.

## 5.2 Plan Definition Model

Plans define:

-   Maximum projects
-   Maximum content entries
-   Storage quota
-   API request limits
-   Feature flag matrix
-   User seat limits

Plan definitions must be versioned and immutable.

## 5.3 Plan Enforcement Architecture

Enforcement must occur at:

-   API middleware (real-time quota checks from a low-latency quota store)
-   Domain service layer (hard limits for write-path operations)
-   Usage metering service (asynchronous overage calculation and billing
    reconciliation)

Quota enforcement contract:

-   PostgreSQL quota ledger is the authoritative source of truth
-   In-memory/Redis counters are a latency optimization layer only
-   On cache miss/staleness, middleware must fallback to the quota ledger
-   API request limits apply to both read and write endpoints
-   If both cache and ledger are unavailable, mutating requests fail
    closed with `503 Service Unavailable`
-   Read-only delivery endpoints may use an emergency tenant-scoped
    read budget only when last-known-good counters are <= 15 minutes old
-   Emergency read budget seed per outage window:
    `min(max(100, ceil(1% of tenant daily read quota)), 5000)` requests
-   If no valid last-known-good counter snapshot exists, read endpoints
    fail closed with `503 Service Unavailable` (no emergency budget)
-   When emergency budget is exhausted, return `429 Too Many Requests`
    with `Retry-After: 60`
-   Emergency-budget read requests emit provisional usage events with
    outage window IDs for deterministic post-recovery reconciliation
-   Emergency budget resets to zero immediately after quota dependency
    recovery and successful ledger backfill completion
-   Clients may retry mutating requests only with the same
    `Idempotency-Key`
-   All mutating endpoints must enforce idempotency-key deduplication
    (minimum 24-hour replay window)

Frontend gating is insufficient for enforcement.
Asynchronous billing aggregates must not be the sole request-time
allow/deny source.

------------------------------------------------------------------------

# 6. Usage Metering System

## 6.1 Metrics Tracked

-   API request count
-   Media storage consumption
-   Bandwidth usage
-   Content creation count
-   User seats
-   Feature utilization

## 6.2 Metering Architecture

Request → Quota Check (Cache → Ledger Fallback) → Response + Event
Emission → Quota Counter Update + Aggregation Worker → Usage Metrics
Store → Billing Engine → Tenant Dashboard

Periodic reconciliation jobs compare cached counters against the
authoritative ledger and repair drift.

Metering must be asynchronous and decoupled from request latency.

------------------------------------------------------------------------

# 7. Feature Flag Governance

## 7.1 Flag Types

-   Plan-based flags
-   Beta rollout flags
-   Tenant override flags
-   Experimental feature toggles

## 7.2 Evaluation Strategy

Flags must be evaluated:

-   Server-side
-   Cached with TTL
-   Tenant-scoped

Client-side feature checks are supplementary only.

------------------------------------------------------------------------

# 8. Identity & Access Architecture

## 8.1 Tenant-Level RBAC

Roles:

-   Owner
-   Admin
-   Editor
-   Viewer

Permission enforcement must be declarative and server-side.

## 8.2 SaaS Administrative Layer

Global administrators manage:

-   Tenant suspensions
-   Plan overrides
-   Fraud detection
-   System monitoring
-   Abuse mitigation

Administrative access must be audited and scoped.

------------------------------------------------------------------------

# 9. Public Delivery API Design

## 9.1 Architectural Requirements

-   Stateless
-   Cache-optimized
-   Edge-compatible
-   Slug-indexed
-   No heavy joins
-   PostgreSQL native full-text search (`tsvector` + `GIN`)

## 9.2 Performance Model

Delivery API must:

-   Serve pre-normalized JSON
-   Support CDN caching
-   Provide ETag support
-   Evaluate lifecycle policy at API key validation time only
-   Deny suspended/archived/deleted tenants without invoking billing
    workflows
-   Purge tenant-tagged cache objects on lifecycle state changes
-   Enforce max cache TTL of 300 seconds for lifecycle-sensitive delivery
    responses
-   If purge fails or backlog grows, tenant requests must bypass stale
    cache and revalidate at origin until purge confirmation

Delivery performance must remain independent of billing logic.

------------------------------------------------------------------------

# 10. Observability Architecture

Production SaaS requires:

## 10.1 Logging

-   Structured request logs
-   Error logs
-   Security events
-   Audit logs
-   Billing anomalies

## 10.2 Metrics

-   API latency
-   Error rate
-   Tenant-level performance
-   Storage growth
-   Usage spikes
-   Entitlement snapshot replication lag and stale-state reject count
-   Revocation propagation lag and revocation dependency availability
-   Quota dependency fallback rate (cache->ledger) and emergency-budget
    activation count
-   Fail-closed decision rate by reason (entitlement, revocation, quota)

## 10.3 Alerting

-   Rate limit violations
-   Subscription failures
-   Abnormal traffic
-   System health degradation
-   Entitlement lag breach (> 60 seconds sustained) or stale-state
    fail-closed spikes
-   Revocation propagation breach (> 60 seconds) or dependency outages
    longer than 2 minutes
-   Quota fallback rate above steady-state threshold (> 1%) or emergency
    budget exhaustion spikes

Observability must be implemented before scaling beyond MVP.

## 10.4 Service Objectives (SLO/SLI Targets)

-   API availability SLO: >= 99.5% monthly
-   Public delivery latency SLO: p95 <= 250ms (CDN hit), p95 <= 700ms
    (origin miss)
-   Authenticated write API latency SLO: p95 <= 800ms
-   5xx error-rate SLO: < 1.0% over rolling 5-minute windows
-   SLI windows: 5-minute error windows, 15-minute latency windows, and
    monthly availability windows
-   Alert trigger baseline: page on-call when latency/error SLOs breach
    for two consecutive windows
-   Entitlement replication SLO: 99% of updates applied within 60 seconds;
    0 requests served with entitlement state older than 120 seconds
-   Revocation enforcement SLO: 99.9% of revocations enforced within 60
    seconds across cache + authoritative fallback paths
-   Quota fallback SLO: cache->ledger fallback rate < 1% of total requests
    in steady state

SLI systems of record:

-   Availability SLO: API gateway uptime + synthetic checks
-   Public delivery latency SLO: CDN edge telemetry (hit path) and origin
    API traces (miss path)
-   Authenticated write latency SLO: application APM traces
-   5xx error-rate SLO: API gateway + application error metrics
-   Entitlement replication SLO: event bus lag + replicated snapshot age
    metrics
-   Revocation enforcement SLO: auth middleware decision logs + revocation
    pipeline lag metrics
-   Quota fallback SLO: quota middleware counters and reconciliation
    worker telemetry

------------------------------------------------------------------------

# 11. Security Architecture

## 11.1 Security Controls

-   Role-Based Access Control
-   API key rotation
-   Provider-issued upload signature expiration
-   Input validation
-   Rate limiting
-   IP throttling
-   Suspicious usage detection

## 11.2 Data Protection

-   Encrypted storage at rest
-   Encrypted transit (TLS)
-   Access logging
-   Secure secret management

------------------------------------------------------------------------

# 12. Scalability Blueprint

## 12.1 Horizontal Scaling

Stateless APIs allow:

-   Automatic horizontal scaling
-   Stateless instance expansion
-   Load balancing across regions

## 12.2 Future Scaling Layers

-   Redis caching layer
-   Queue-based background workers
-   Distributed event processing
-   Read-replica databases
-   Edge rendering optimization

------------------------------------------------------------------------

# 13. Disaster Recovery & Resilience

## 13.1 Backup Strategy

-   Automated daily full database backups
-   Continuous WAL archiving with Point-in-Time Recovery (PITR)
-   Incremental snapshots
-   Storage redundancy

## 13.2 Recovery Objectives

-   RTO target: <= 4 hours for core API and tenant operations
-   RPO target: <= 1 hour for primary content metadata
-   RPO target: <= 24 hours for derived metering/analytics projections

## 13.3 Restore Validation Cadence

-   Quarterly full-environment restore drills from production backups into
    isolated recovery environments
-   Monthly table-level restore spot checks for tenant content and
    identity/auth tables
-   Drill pass criteria: restore within RTO <= 4 hours and verified data
    loss <= RPO targets
-   Post-drill remediation actions tracked with owners and due dates
    within 14 calendar days

## 13.4 Failure Handling

System must tolerate:

-   Partial billing outages
-   Storage delays
-   Temporary database failures

Graceful degradation is mandatory.

------------------------------------------------------------------------

# 14. Compliance & Data Governance

The architecture must prepare for:

-   Tenant data export
-   Tenant data deletion
-   Audit log retention
-   Content revision immutability
-   Right-to-erasure handling for immutable records through
    anonymization/tombstoning
-   Regulatory compliance readiness

Data deletion must cascade across database, storage, and derived search
indexes while preserving only minimally required immutable audit traces.

## 14.1 Retention Matrix (Baseline)

-   Tenant content and primary metadata: hard delete within 30 days after
    confirmed tenant deletion unless legal hold applies
-   Immutable audit trails: retain 13 months and anonymize subject
    identity fields during right-to-erasure workflows
-   Security event logs: retain 12 months (90 days hot, remaining period
    cold archive)
-   Derived metering analytics: retain 24 months in aggregated/anonymized
    form
-   Billing/invoice artifacts: retain per legal/tax requirements
    (typically up to 7 years)

------------------------------------------------------------------------

# 15. SaaS Evolution Roadmap

## Phase 1

-   Multi-tenant isolation
-   Subscription enforcement
-   Basic usage tracking

## Phase 2

-   Usage-based billing
-   Feature flag expansion
-   Tenant analytics dashboard

## Phase 3

-   Enterprise tiers
-   Dedicated infrastructure options
-   SLA enforcement
-   Custom domain provisioning
-   White-label capability

------------------------------------------------------------------------

# 16. Engineering Maturity Assessment

This SaaS architecture demonstrates:

-   Control/Data plane separation
-   Lifecycle-driven governance
-   Multi-layer isolation
-   Asynchronous metering strategy
-   Production observability planning
-   Horizontal scaling readiness
-   Enterprise-grade extensibility

It represents a fully scalable SaaS transformation blueprint.

------------------------------------------------------------------------

End of Enterprise SaaS Architecture Blueprint
