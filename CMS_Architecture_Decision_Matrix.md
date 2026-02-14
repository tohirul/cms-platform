# CMS Platform --- Architecture Decision Matrix

## Purpose

This document is the canonical architecture source of truth for all
platform documentation. When any decision below changes, dependent docs
must be updated in the same change set.

------------------------------------------------------------------------

## Decision Matrix

| Area | Canonical Decision | Enforcement Notes |
| --- | --- | --- |
| Frontend Control Plane | Next.js 15 (App Router) on Vercel | Control-plane UI calls backend over secured REST |
| Backend Data Plane | Node.js + Express on Render Free Tier | Decoupled runtime, stateless API instances |
| Database | PostgreSQL (Supabase) + Drizzle ORM | Tenant boundaries enforced through RLS |
| AuthN/AuthZ | Supabase Auth JWTs validated in Express | Request context forwarded to DB for RLS evaluation |
| Tenant Isolation | PostgreSQL RLS primary, service-layer checks secondary | Fail-closed when tenant/user context missing |
| Media | Cloudinary/UploadThing direct upload + optimized delivery | Backend stores metadata only; no raw media processing |
| Editor | Tiptap headless editor with structured JSON output | JSON normalized and persisted in PostgreSQL |
| Search | PostgreSQL native full-text search (`tsvector` + `GIN`) | Tenant-scoped queries under same RLS boundaries |
| Delivery Lifecycle | Entitlement snapshot (target <=60s lag, stale >120s) | Lifecycle-sensitive delivery fails closed when stale/unavailable |
| Cold Start Mitigation | `GET /health` keep-alive ping via cron | Required for Render free-tier demo responsiveness |
| Quota/Retry Safety | Authoritative PostgreSQL quota ledger + idempotency keys | Mutations fail closed when quota dependencies unavailable |
| SRE Baseline | Defined SLOs/SLIs + windows + paging thresholds | Metrics must include entitlement/revocation/quota fallback |
| DR & Compliance | PITR backups, RTO/RPO targets, restore drills, retention matrix | Legal-hold-aware deletion and immutable audit handling |

------------------------------------------------------------------------

## Terminology Guardrails

Preferred architecture wording:

-   `Cloudinary/UploadThing direct upload`
-   `Node.js/Express on Render Free Tier`
-   `PostgreSQL (Supabase) + Drizzle + RLS`
-   `Supabase Auth JWT validation`

Avoid legacy wording:

-   `Signed URL upload flow` (as primary media model)
-   `Backend: Serverless API functions` (for this architecture)
-   `Managed object storage` (as generic storage architecture label)

------------------------------------------------------------------------

## Change Control

A documentation change is complete only when:

1.  This matrix remains accurate.
2.  Related architecture docs are aligned in the same PR/commit.
3.  `scripts/lint_architecture_docs.sh` passes.

