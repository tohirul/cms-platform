# CMS Platform Roadmap

## Vision

A headless CMS to replace WordPress entirely — multi-tenant, API-first, extensible via hooks, with native features that WordPress relies on plugins for.

---

## Roadmap Overview

```
═══════════════════════════════════════════════════════════════════════════════════
                                    TIMELINE
═══════════════════════════════════════════════════════════════════════════════════

Q1 2026          Q2 2026          Q3 2026          Q4 2026
┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│  FOUNDATION │ │   CORE CMS  │ │  EXTENSIBLE │ │  ENTERPRISE │
│  (Ph 1-4)   │ │  (Ph 5-11)  │ │  (Ph 12-20) │ │  (Ph 21-28) │
└─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘
```

---

## Phase 1: Foundation (Months 1-2)

### Goal: Core infrastructure and content management

| Month | Feature               | CMS-Feature.md      | Implementation        |
| ----- | --------------------- | ------------------- | --------------------- |
| 1     | Multi-Tenancy Core    | Phase 13            | Backend B1-B3         |
| 1     | Database Schema + RLS | Phase 1             | Backend B2            |
| 1     | JWT Auth + RBAC       | Phase 3 (Feature 4) | Backend B3            |
| 1     | Content CRUD API      | Phase 1             | Backend B4            |
| 2     | Block Editor (Tiptap) | Phase 1 (Feature 2) | Frontend              |
| 2     | Media Library         | Phase 2 (Feature 3) | Backend B4 + Frontend |
| 2     | Revisions & Autosave  | Phase 3 (Feature 5) | Backend B4            |

**Deliverables:**

- [x] Multi-tenant PostgreSQL schema with RLS
- [x] Supabase JWT authentication
- [x] Content CRUD API with versioning
- [x] Tiptap-based block editor
- [x] Media upload to Cloudinary/UploadThing

**Dependencies:**

```
Supabase Auth → JWT Middleware → Tenant Resolution → RLS Enforcement
                                                    ↓
                                          Content API ← Content Nodes
                                                    ↓
                                          Media API ← Assets
```

---

## Phase 2: Core CMS (Months 3-4)

### Goal: Feature parity with basic WordPress

| Month | Feature               | CMS-Feature.md        | Implementation |
| ----- | --------------------- | --------------------- | -------------- |
| 3     | Hooks System          | Phase 5 (Feature 8)   | Backend B8     |
| 3     | Global Settings       | Phase 4 (Feature 6)   | Backend B5     |
| 3     | SEO/Meta              | Phase 4 (Feature 7)   | Frontend       |
| 3     | Job Queue             | Phase 10 (Feature 14) | Backend B9     |
| 4     | Full-Text Search      | Phase 7 (Feature 10)  | Backend B5     |
| 4     | i18n / Multi-language | Phase 7 (Feature 11)  | Backend B10    |
| 4     | Public API            | Phase 11 (Feature 16) | Backend B5     |

**Deliverables:**

- [x] HookRegistry (actions + filters)
- [x] Settings panel with JSONB storage
- [x] Dynamic SEO + sitemap generation
- [x] PostgreSQL job queue with workers
- [x] PostgreSQL FTS with tsvector
- [x] i18n with [lang] routing
- [x] Read-only public API with API keys

**Dependencies:**

```
HookRegistry ──→ Job Queue ──→ Webhook Dispatch
      ↓               ↓
Audit Logs     Scheduled Posts
      ↓
Email Engine (Phase 24)
```

---

## Phase 3: Extensible CMS (Months 5-6)

### Goal: WordPress plugin-like extensibility

| Month | Feature            | CMS-Feature.md        | Implementation |
| ----- | ------------------ | --------------------- | -------------- |
| 5     | Comments System    | Phase 6 (Feature 9)   | New Phase      |
| 5     | Form Builder       | Phase 8 (Feature 12)  | New Phase      |
| 5     | RSS/Atom Feeds     | Phase 11 (Feature 15) | Backend B10    |
| 5     | Email Engine       | Phase 24 (Feature 31) | New Phase      |
| 6     | Webhooks           | Phase 19 (Feature 26) | New Phase      |
| 6     | Transients API     | Phase 27 (Feature 35) | New Phase      |
| 6     | Draft Mode/Preview | Phase 18 (Feature 24) | New Phase      |

**Deliverables:**

- [x] Nested comments with Materialized Paths
- [x] Drag-drop form builder
- [x] Form submissions storage
- [x] RSS/Atom feed generation
- [x] Pluggable email (SMTP/SES/Resend)
- [x] Webhook management UI
- [x] Transient caching system
- [x] Next.js Draft Mode preview

**Dependencies:**

```
Form Builder → Form Submissions → Admin UI
      ↓
Email Engine ← Hooks
      ↓
Webhooks ← Job Queue
```

---

## Phase 4: Enterprise (Months 7-8)

### Goal: Enterprise features and monetization readiness

| Month | Feature              | CMS-Feature.md        | Implementation |
| ----- | -------------------- | --------------------- | -------------- |
| 7     | Image Editor         | Phase 12 (Feature 17) | New Phase      |
| 7     | Audit Logs           | Phase 15 (Feature 20) | New Phase      |
| 7     | 2FA / Auth Hardening | Phase 15 (Feature 21) | New Phase      |
| 7     | Cache Invalidation   | Phase 18 (Feature 25) | New Phase      |
| 8     | Content Gating       | Phase 16 (Feature 22) | New Phase      |
| 8     | Dashboard Widgets    | Phase 17 (Feature 23) | New Phase      |
| 8     | Template System      | Phase 13 (Feature 19) | New Phase      |

**Deliverables:**

- [x] In-browser image editor (crop/rotate)
- [x] Comprehensive audit trail
- [x] TOTP-based 2FA
- [x] Granular cache invalidation
- [x] Premium content gating
- [x] Pluggable dashboard widgets
- [x] Database-stored templates

**Dependencies:**

```
2FA → Session Management → Post Locking (Phase 26)
      ↓
Audit Logs ← Hooks
      ↓
Content Gating ← Subscriptions ← Webhooks (Stripe)
```

---

## Phase 5: Advanced (Months 9-10)

### Goal: Migration tools and advanced features

| Month | Feature           | CMS-Feature.md        | Implementation |
| ----- | ----------------- | --------------------- | -------------- |
| 9     | WXR Importer      | Phase 21 (Feature 28) | New Phase      |
| 9     | oEmbed Resolution | Phase 22 (Feature 29) | New Phase      |
| 9     | Shortcodes        | Phase 23 (Feature 30) | New Phase      |
| 9     | System Health     | Phase 20 (Feature 27) | New Phase      |
| 10    | mu-plugins        | Phase 28 (Feature 36) | New Phase      |
| 10    | API Tokens        | Phase 26 (Feature 34) | New Phase      |
| 10    | Real-time Sync    | Phase 26 (Feature 33) | New Phase      |

**Deliverables:**

- [x] WordPress WXR importer
- [x] YouTube/Twitter/Spotify oEmbed
- [x] AST-based shortcode parser
- [x] System health dashboard
- [x] Immutable boot modules
- [x] Application passwords
- [x] Post locking + heartbeat

---

## Implementation Dependencies

### Critical Path

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CRITICAL PATH                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Auth (B3) ──→ Content API (B4) ──→ Hooks (B8) ──→ Job Queue (B9)           │
│      │              │                │                │                     │
│      ↓              ↓                ↓                ↓                     │
│  RBAC          Revisions         Webhooks         Scheduled                 │
│                                  (Phase 19)       Publishing                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Feature Dependencies Graph

```
                    ┌──────────────┐
                    │  Multi-Tenancy │
                    │   (Foundation) │
                    └───────┬────────┘
                            │
          ┌─────────────────┼─────────────────┐
          │                 │                 │
          ↓                 ↓                 ↓
    ┌───────────┐    ┌───────────┐    ┌───────────┐
    │   Auth    │    │  Content  │    │   Media   │
    │   (B3)    │    │   (B4)    │    │   (B4)    │
    └─────┬─────┘    └─────┬─────┘    └─────┬─────┘
          │                │                │
          └────────────────┼────────────────┘
                           │
                    ┌──────┴──────┐
                    │   Hooks     │
                    │   (B8)      │
                    └──────┬──────┘
                           │
     ┌──────────┬──────────┼──────────┬──────────┐
     │          │          │          │          │
     ↓          ↓          ↓          ↓          ↓
┌────────┐ ┌────────┐ ┌────────┐ ┌────────-┐ ┌──────────┐
│ Audit  │ │Webhooks│ │ Email  │ │Scheduled│ │Transients│
│ Logs   │ │        │ │ Engine │ │Posts    │ │          │
└────────┘ └────────┘ └────────┘ └───────-─┘ └──────────┘
     │          │          │          │
     └──────────┴──────────┴──────────┘
                           │
                    ┌──────┴──────┐
                    │   Preview   │
                    │   Mode      │
                    └─────────────┘
```

---

## Milestones

| Milestone      | Date         | Criteria                                       |
| -------------- | ------------ | ---------------------------------------------- |
| M1: Alpha      | End Month 2  | Multi-tenant, auth, content CRUD, block editor |
| M2: Beta       | End Month 4  | Hooks, search, i18n, public API                |
| M3: RC1        | End Month 6  | Forms, comments, email, webhooks               |
| M4: RC2        | End Month 8  | 2FA, audit logs, content gating                |
| M5: Production | End Month 10 | All 36 features from CMS-Feature.md            |

---

## Resource Allocation

### Backend (Node.js/Express + PostgreSQL)

- **Phase 1**: 2 engineers, 160 hours
- **Phase 2**: 2 engineers, 200 hours
- **Phase 3**: 1 engineer, 160 hours
- **Phase 4**: 1 engineer, 160 hours
- **Phase 5**: 1 engineer, 160 hours

### Frontend (Next.js + React)

- **Phase 1**: 1 engineer, 120 hours
- **Phase 2**: 1 engineer, 120 hours
- **Phase 3**: 1 engineer, 120 hours
- **Phase 4**: 1 engineer, 120 hours
- **Phase 5**: 1 engineer, 80 hours

---

## Risk Matrix

| Risk                         | Impact | Likelihood | Mitigation             |
| ---------------------------- | ------ | ---------- | ---------------------- |
| Hooks system too complex     | High   | Medium     | Start simple, iterate  |
| i18n schema changes breaking | High   | Low        | Version content JSON   |
| Job queue race conditions    | Medium | Low        | FOR UPDATE SKIP LOCKED |
| WXR parser edge cases        | Medium | Medium     | Incremental parsing    |
| Cold-start on free tier      | Medium | High       | Health check cron      |

---

## Quick Start (Next 30 Days)

```
Week 1-2: Backend B1-B3 (Auth, Schema, RLS)
Week 3:   Backend B4 (Content CRUD)
Week 4:   Frontend (Block Editor + Media)
```

---

End of Roadmap
