# CMS-Feature.md Alignment & Resolution Log

This document tracks resolutions to contradictions and gaps between `CMS-Feature.md` and other architecture documents.

---

## Resolved Contradictions

### 1. Media Handling (Phase 2)

| CMS-Feature.md | Existing Architecture | Resolution |
|----------------|----------------------|------------|
| "Rely heavily on Next.js `<Image />` for on-the-fly optimization" | Cloudinary/UploadThing CDN | **Kept existing** - CDN edge transformations are faster, zero origin CPU |

**Rationale**: Cloudinary/UploadThing handle transformations at edge (closer to user), reducing latency vs. origin-based Next.js Image component.

**Updated**: `CMS_Technical_Architecture_Deep_Dive.md` Section 8.1 with resolution note.

---

### 2. Multi-Tenancy Scope (Phase 13)

| CMS-Feature.md | Existing Architecture | Resolution |
|----------------|----------------------|------------|
| "Optional but Powerful" | Core design principle | **Existing wins** - Multi-tenancy is foundational |

**Rationale**: The entire architecture (RLS, tenant scoping, API segmentation) is built around multi-tenancy. Making it optional would break core design decisions.

---

## Added Missing Features

### Phase 5: Hooks System

**Status**: Added to `CMS_Technical_Architecture_Deep_Dive.md` as Section 16

Added:
- Event Hooks (doAction) - onContentPublish, onUserRegister, etc.
- Filters (applyFilters) - content_output, seo_metadata, email_template
- Modular plugin architecture (/system-modules, /plugins, /modules)

**Implementation**: Added Phase B8 to `BACKEND_IMPLEMENTATION_PLAN.md`

---

### Phase 10: Job Queue

**Status**: Added to `CMS_Technical_Architecture_Deep_Dive.md` as Section 17

Added:
- PostgreSQL-backed job queue
- FOR UPDATE SKIP LOCKED for concurrent workers
- Admin dashboard for monitoring

**Implementation**: Added Phase B9 to `BACKEND_IMPLEMENTATION_PLAN.md`

---

### Phase 11: i18n & RSS

**Status**: Added to `CMS_Technical_Architecture_Deep_Dive.md` as Section 18

Added:
- Single row with locale keys in JSONB
- Next.js [lang] dynamic routing
- RSS/Atom feed generation

**Implementation**: Added Phase B10 to `BACKEND_IMPLEMENTATION_PLAN.md`

---

### Phase 24: Email Engine

**Status**: Added to `CMS_Technical_Architecture_Deep_Dive.md` as Section 19

Added:
- Central cms.sendEmail() utility
- Adapter pattern (SMTP, AWS SES, Resend)
- Hook integration for interceptors
- React Email for templating

---

### Phase 27: Transients API

**Status**: Added to `CMS_Technical_Architecture_Deep_Dive.md` as Section 20

Added:
- transients table (key, value JSONB, expiration_time)
- setTransient/getTransient helpers
- Background cleanup via job queue

---

### Phase 28: mu-plugins

**Status**: Added to `CMS_Technical_Architecture_Deep_Dive.md` as Section 21

Added:
- /system-modules/ directory
- Auto-load before standard registry
- Enterprise use cases (security, network policies)

---

## Aligned Features

| Feature | Status | Notes |
|---------|--------|-------|
| CPTs & Taxonomies | ✅ Aligned | JSONB for dynamic attributes |
| Block Editor | ✅ Aligned | Tiptap + JSON storage |
| RBAC | ✅ Aligned | JWT + capabilities matrix |
| Full-Text Search | ✅ Aligned | PostgreSQL FTS with tsvector |
| Public API | ✅ Aligned | Read-only, tenant-scoped |
| Versioning | ✅ Aligned | Immutable revisions |

---

## Cross-Document Reference

- **CMS-Feature.md** - Feature checklist (28 phases, 36 features)
- **CMS_Technical_Architecture_Deep_Dive.md** - Technical architecture (now includes Phase 5, 10, 11, 24, 27, 28)
- **BACKEND_IMPLEMENTATION_PLAN.md** - Implementation phases (now includes B8, B9, B10)
- **CMS_Feature_Based_System_Design_Blueprint.md** - Feature matrix (15 features - needs update)
- **CMS_Architecture_Decision_Matrix.md** - ADRs

---

## Remaining Work

1. Update `CMS_Feature_Based_System_Design_Blueprint.md` to include Hooks, Job Queue, Transients, Email
2. Add remaining phases to implementation plan (Forms, Comments, Webhooks, etc.)
3. Create detailed ADR for each major architectural decision

---

End of Alignment Log