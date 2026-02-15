# Backend Implementation Plan

**Scope**: Data Plane API for CMS Platform  
**Stack**: Node.js, Express.js, PostgreSQL (Supabase), Drizzle ORM, Supabase Auth JWT  
**Deployment Target**: Render Free Tier  
**Architecture Source of Truth**: `CMS_Architecture_Decision_Matrix.md`  
**Date**: February 14, 2026

---

## 1. Objectives

- Deliver a decoupled Express REST API enforcing tenant isolation with PostgreSQL RLS.
- Implement secure JWT validation, tenant-scoped business logic, and lifecycle-aware delivery controls.
- Provide content, media metadata, publishing/versioning, search, and governance endpoints.
- Ensure operational resilience with observability, health checks, and recovery-ready policies.

---

## 2. Non-Goals (Initial Delivery)

- Multi-region active-active deployment.
- Event-sourcing rewrite of content persistence.
- Enterprise SSO/SAML integrations.

---

## 3. Phase Plan

## Phase B1: Service Foundation and Runtime Baseline

**Type**: Infrastructure  
**Estimated**: 6-8 hours

**Deliverables**

- Express app bootstrap with config management and structured logging.
- Centralized error model and request correlation IDs.
- Health endpoint (`GET /health`) for keep-alive and uptime checks.
- **Safe Query Transaction Wrapper**: A helper function (e.g., `safeQuery` or `withRls`) that wraps Drizzle operations in a transaction and executes `set_config('app.tenant_id', ...)` to ensure RLS policies work.

**Implementation Tasks**

- Create app entrypoint, router mounting, and middleware order.
- Add env validation and config loading.
- Add global error handler and consistent API error responses.
- Implement the RLS transaction wrapper to guarantee tenant context is set before any database query.

**Verification Criteria**

- Service boots in local and preview environments.
- `/health` returns fast liveness signal.
- Standardized error payloads for 400/401/404/500 are stable.

**Exit Criteria**

- Runtime foundation supports secure feature layering.

---

## Phase B2: Database Schema and RLS Enforcement

**Type**: Database  
**Estimated**: 10-14 hours

**Deliverables**

- Core schema (tenants, users, projects, content, revisions, assets, api_keys, quotas).
- Tenant-scoped RLS policies on all tenant-owned tables.
- Drizzle schema + migration workflow.

**Implementation Tasks**

- Define normalized relational model and indexes.
- Implement RLS policies using tenant/user claim context.
- Add migration scripts and local/dev bootstrap commands.

**Verification Criteria**

- CRUD works for valid tenant context.
- Cross-tenant reads/writes are blocked by DB layer.
- Missing tenant context fails closed.

**Exit Criteria**

- Persistence layer enforces isolation independent of app logic.

---

## Phase B2.5: Demo Data Seeding

**Type**: Data / Onboarding  
**Estimated**: 4-6 hours

**Deliverables**

- Robust seeding script (`npm run seed`) to populate the CMS.
- "Agency", "SaaS", and "Blog" demo tenants with distinct content types.
- Dummy users, content entries, and revisions for each tenant.

**Implementation Tasks**

- Create seed data JSON files for multiple tenant archetypes.
- Implement a seeding utility using the `safeQuery` wrapper to insert data with correct RLS context.
- Ensure idempotent execution (don't duplicate data on re-runs).

**Verification Criteria**

- Database is populated with rich, realistic data for demos.
- Frontend dashboard shows meaningful content immediately after setup.

**Exit Criteria**

- Resume demo environment is never empty.

---

## Phase B3: Authentication, Authorization, and Request Context

**Type**: API  
**Estimated**: 8-12 hours

**Deliverables**

- Supabase JWT validation middleware in Express.
- Tenant/user claim extraction and request context propagation.
- Revocation checks and fail-closed behavior for dependency outages.

**Implementation Tasks**

- Validate bearer tokens and claim integrity.
- Apply role/permission checks at service boundaries.
- Set request-scoped DB context for RLS (`tenant_id`, `user_id`, `role`).

**Verification Criteria**

- 401 for invalid/expired/missing tokens.
- 403 for insufficient role permissions.
- Revoked-token paths blocked according to policy.

**Exit Criteria**

- AuthN/AuthZ and DB context propagation are production-safe.

---

## Phase B4: Core Content and Media Metadata APIs

**Type**: API  
**Estimated**: 12-16 hours

**Deliverables**

- Tenant-scoped content CRUD endpoints.
- Revision snapshot creation and retrieval.
- Media upload signature endpoints + metadata persistence APIs.

**Implementation Tasks**

- Implement schema validation (Zod) and service-layer invariants.
- Add versioning hooks for publish-related mutations.
- Integrate Cloudinary/UploadThing signature/token generation flow.

**Verification Criteria**

- Content CRUD and revision creation succeed for authorized tenant.
- Validation errors return deterministic messages.
- Media signature flow returns short-lived valid upload tokens.

**Exit Criteria**

- Editorial and media platform primitives are complete.

---

## Phase B5: Delivery API, Search, and Lifecycle Controls

**Type**: API  
**Estimated**: 10-14 hours

**Deliverables**

- Public read-optimized delivery endpoints.
- PostgreSQL FTS search endpoints (`tsvector`/`GIN` backed).
- Lifecycle entitlement checks with stale-state fail-closed behavior.

**Implementation Tasks**

- Implement slug/type retrieval with minimal query overhead.
- Add tenant-scoped full-text query endpoints.
- Enforce lifecycle contract: trial/active/grace allow, suspended/archive/delete deny.

**Verification Criteria**

- Delivery endpoints are read-only and cache-friendly.
- Search results remain tenant-scoped and relevant.
- Stale/unavailable entitlement state blocks lifecycle-sensitive delivery as specified.

**Exit Criteria**

- Public API behavior matches governance and performance constraints.

---

## Phase B6: Quotas, Metering, and Idempotency

**Type**: Integration  
**Estimated**: 10-14 hours

**Deliverables**

- Authoritative PostgreSQL quota ledger and cache fallback logic.
- Metering event emission and reconciliation jobs.
- Idempotency-key enforcement on mutating endpoints.

**Implementation Tasks**

- Implement request-time quota checks and fail-closed mutation behavior.
- Add emergency read budget logic per documented policy.
- Add replay-safe deduplication window for `Idempotency-Key`.

**Verification Criteria**

- Quota violations return 429 with consistent structure.
- Mutation retries with same idempotency key do not duplicate side effects.
- Reconciliation repairs cache/ledger drift.

**Exit Criteria**

- Billing-adjacent controls are deterministic and audit-friendly.

---

## Phase B7: Observability, Security Hardening, and Resilience

**Type**: Testing  
**Estimated**: 10-14 hours

**Deliverables**

- Metrics and logs for latency, errors, entitlement lag, revocation lag, quota fallback.
- Alert thresholds aligned to SLO/SLI windows.
- Backup/recovery runbook alignment hooks.

**Implementation Tasks**

- Instrument API and worker paths with structured metrics.
- Add rate limiting, abuse guardrails, and security event logs.
- Validate keep-alive cron workflow for Render free-tier cold-start mitigation.

**Verification Criteria**

- SLI windows and page-trigger conditions are measurable in telemetry.
- Security events are captured with required context.
- Cold-start behavior improves under keep-alive checks.

**Exit Criteria**

- Backend is operationally observable, secure, and production-releasable.

---

## 4. Core API Surface (Initial)

- `GET /health`
- `GET /v1/content`
- `POST /v1/content`
- `PATCH /v1/content/:id`
- `DELETE /v1/content/:id`
- `POST /v1/content/:id/publish`
- `POST /v1/content/:id/rollback`
- `GET /v1/search`
- `POST /v1/media/signature`
- `POST /v1/media/metadata`
- `GET /v1/tenants/:tenantId/usage`

---

## 5. Environment Variables (Backend)

- `PORT`
- `NODE_ENV`
- `DATABASE_URL`
- `SUPABASE_JWT_SECRET` or JWKS configuration variables
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY` (if required for controlled admin operations)
- `CLOUDINARY_*` or UploadThing credentials
- `QUOTA_CACHE_URL` (optional cache layer)
- `LOG_LEVEL`

---

## 6. Risks and Mitigations

- RLS misconfiguration: enforce policy tests in CI before deploy.
- Token-validation edge cases: include clock-skew and revocation-path tests.
- Quota-path complexity: validate fallback and reconciliation through load/failure scenarios.
- Free-tier sleep and latency: keep `/health` ping cadence and resilient timeout/retry patterns.
- **SSG Limitation**: Lack of Webhooks in Phase B1-B7 means Static Site Generation clients cannot automatically revalidate/rebuild on content changes.

---

## 7. Final Go/No-Go Checklist

- Auth, RLS, and tenant isolation tests pass.
- Content/media/search/delivery endpoints meet expected behavior.
- Quota and idempotency controls verified under retry/failure cases.
- Observability and alert rules emit expected signals.
- Render deployment stable with health-check keep-alive in place.
