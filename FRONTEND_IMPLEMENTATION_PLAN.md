# Frontend Implementation Plan

**Scope**: Control Plane UI for CMS Platform  
**Stack**: Next.js 15 (App Router), Tailwind CSS, shadcn/ui, Supabase Auth  
**Deployment Target**: Vercel  
**Architecture Source of Truth**: `CMS_Architecture_Decision_Matrix.md`  
**Date**: February 14, 2026

---

## 1. Objectives

- Build a production-grade admin control plane for multi-tenant CMS operations.
- Integrate Supabase Auth with JWT-based API calls to Express backend.
- Deliver structured content authoring (Tiptap), media workflows, and tenant governance UX.
- Ship with measurable quality gates and release readiness checks.

---

## 2. Non-Goals (Initial Delivery)

- Public website rendering engine implementation.
- Full plugin marketplace UI.
- Real-time collaboration editing.

---

## 3. Phase Plan

## Phase F1: Foundation and App Shell

**Type**: Infrastructure  
**Estimated**: 6-8 hours

**Deliverables**

- Next.js 15 app skeleton with App Router.
- Tailwind + shadcn/ui setup and design tokens.
- Base layout, navigation shell, error/loading boundaries.

**Implementation Tasks**

- Initialize Next.js project structure and route groups.
- Add app-level providers (theme, query cache if used, auth context).
- Implement baseline pages: dashboard home, login placeholder, 404, error states.

**Verification Criteria**

- App builds without warnings.
- Core routes render on desktop/mobile.
- Error and loading boundaries render expected fallback UI.

**Exit Criteria**

- Stable shell exists for feature layering without structural rewrites.

---

## Phase F2: Authentication and Tenant Context

**Type**: Integration  
**Estimated**: 8-10 hours

**Deliverables**

- Supabase Auth login/logout/session restore.
- Route protection for admin pages.
- Tenant/workspace selector and session-bound tenant context.

**Implementation Tasks**

- Integrate Supabase client SDK for browser + server usage boundaries.
- Implement auth middleware/guards for protected routes.
- Ensure API requests include `Authorization: Bearer <jwt>`.

**Verification Criteria**

- Unauthenticated users are redirected from protected routes.
- Authenticated users can access dashboard and keep session across reloads.
- Token is attached to backend API calls.

**Exit Criteria**

- Auth + tenant context are reliable enough to gate all subsequent features.

---

## Phase F3: Content Management and Tiptap Authoring

**Type**: UI  
**Estimated**: 12-16 hours

**Deliverables**

- Content list/filter/create/edit UI.
- Tiptap headless editor integration.
- Structured JSON serialization and validation feedback.
- **Read-Only Content Renderer**: A React component to render the structured JSON content for preview and public views.

**Implementation Tasks**

- Build content CRUD screens with optimistic UX where safe.
- Add Tiptap editor with required nodes (text, image, embed, callout).
- Persist and retrieve normalized structured JSON through backend APIs.
- Implement the read-only renderer to visualize the JSON output.

**Verification Criteria**

- Create/edit/delete operations work per tenant scope.
- Editor state round-trips without structural corruption.
- Validation and API errors surface actionable messages.
- Renderer correctly displays all supported block types.

**Exit Criteria**

- Editors can produce and persist publish-ready structured content.

---

## Phase F4: Media Management UX (Cloudinary/UploadThing)

**Type**: Integration  
**Estimated**: 8-12 hours

**Deliverables**

- Upload modal/flow with provider signature request.
- Direct client upload to Cloudinary/UploadThing.
- Asset library UI backed by backend metadata records.

**Implementation Tasks**

- Implement signed upload initiation call to Express endpoint.
- Upload directly from browser to provider CDN.
- Store and display returned asset metadata/preview URLs.

**Verification Criteria**

- Upload succeeds for allowed formats/sizes.
- Failures return user-visible recovery actions.
- Uploaded assets appear in library and can be inserted into content.

**Exit Criteria**

- Media workflow is end-to-end without backend file buffering.

---

## Phase F5: Delivery, Search, and Publishing Workflow UI

**Type**: UI  
**Estimated**: 10-14 hours

**Deliverables**

- Publish/unpublish/schedule controls.
- Revision history and rollback UI.
- Search/filter UI driven by backend PostgreSQL FTS endpoints.

**Implementation Tasks**

- Add publish state transitions and confirmation flows.
- Build revision timeline and rollback action.
- Add keyword search, filters, pagination, and empty-state handling.

**Verification Criteria**

- Publishing actions map cleanly to backend states.
- Rollback restores selected revision correctly.
- Search returns tenant-scoped results with expected latency UX.

**Exit Criteria**

- Editorial workflows are complete for MVP operations.

---

## Phase F6: Governance UX (Lifecycle, Quotas, Feature Flags)

**Type**: Integration  
**Estimated**: 8-12 hours

**Deliverables**

- Lifecycle-state awareness in UI (trial/active/grace/suspended).
- Quota dashboards and limit messaging.
- Feature flag-aware UI gating.

**Implementation Tasks**

- Display lifecycle and plan details in workspace settings.
- Add quota usage bars and over-limit handling UX.
- Hide/disable feature surfaces based on backend-evaluated flags.

**Verification Criteria**

- Suspended/archived states visibly restrict actions.
- Quota breach errors show clear remediation paths.
- Feature toggles alter UI without stale caches after refresh.

**Exit Criteria**

- Tenant governance policies are accurately represented in control plane UX.

---

## Phase F7: Quality, Security, and Release Readiness

**Type**: Testing  
**Estimated**: 8-12 hours

**Deliverables**

- Test coverage for critical user journeys.
- Accessibility and performance pass for major screens.
- Production release checklist for Vercel deployment.

**Implementation Tasks**

- Add component/integration tests for auth, content CRUD, editor, upload flows.
- Add E2E happy-path and failure-path tests.
- Run Lighthouse/accessibility checks and fix priority issues.

**Verification Criteria**

- Critical flows pass in CI.
- No high-severity accessibility violations on core pages.
- Production build and preview deployments are stable.

**Exit Criteria**

- Frontend is production deployable and operationally supportable.

---

## 4. Dependencies

- Express backend APIs for auth validation, content CRUD, media signatures, search, lifecycle, and quotas.
- Supabase project with Auth and required environment variables.
- Cloudinary or UploadThing account and upload configuration.

---

## 5. Environment Variables (Frontend)

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `NEXT_PUBLIC_API_BASE_URL`
- `NEXT_PUBLIC_UPLOAD_PROVIDER` (default: `cloudinary`)

---

## 6. Risks and Mitigations

- JWT/session boundary bugs: enforce strict auth guard tests and token refresh checks.
- Editor complexity growth: keep editor extensions modular and schema-driven.
- Upload UX fragmentation: standardize upload state machine and retry patterns.
- Free-tier latency spikes: surface resilient loading states and retry-safe interactions.

---

## 7. Final Go/No-Go Checklist

- Authenticated and unauthenticated route behavior verified.
- Content, media, publish, search, and rollback workflows pass.
- Tenant lifecycle and quota constraints reflected correctly in UI.
- Critical test suite green; deployment previews validated.
