# CMS Platform

## Multi-Tenant Headless Content Infrastructure System

---

## Overview

CMS Platform is a production-grade, multi-tenant, headless Content
Management System engineered for structured content modeling, scalable
API delivery, and SaaS readiness.

Unlike traditional monolithic CMS systems, this platform strictly
separates:

- Content authoring
- Content storage
- Content transformation
- Public content delivery
- SaaS governance (control plane)

The system is designed for agencies, product teams, and SaaS operators
who require scalable, extensible, and structured content infrastructure.

---

## Core Capabilities

### 1. Multi-Tenant Architecture

- Isolated projects/sites
- Scoped API keys
- Tenant-level storage paths
- Role-based access per tenant

### 2. Structured Content Engine

- Block-based document modeling
- JSON-based normalized content storage
- Version-controlled content revisions
- Metadata and relationship modeling

### 3. Rich Text Editor Integration

- Extensible node-based editor
- Custom block support (image, embed, callout, etc.)
- Slash command architecture
- Structured JSON output

### 4. Visual Page Builder

- Drag-and-drop layout engine
- Component registry system
- Layout and content separation
- Theme configuration layer

### 5. Media Management System

- Cloudinary/UploadThing direct upload flow
- CDN-first media delivery with provider optimization
- Metadata tracking
- Stateless backend integration

### 6. Public Delivery API

- Stateless
- Slug-indexed
- CDN-cache compatible
- Read-optimized responses
- Edge-runtime ready

### 7. SaaS Governance Layer

- Subscription enforcement
- Tenant lifecycle state machine
- Usage metering
- Feature flags
- Plan-based access control

### 8. Typed Client SDK

- Lightweight API abstraction
- Edge-compatible transport
- Cache strategies
- Error normalization
- Multi-tenant awareness

---

## High-Level Architecture

The platform uses a decoupled architecture:

Control Plane (Next.js 15 on Vercel) → Secured REST Calls (Bearer JWT) → Data Plane (Node.js/Express on Render Free Tier) → PostgreSQL (Supabase) + Cloudinary/UploadThing

Request flow:

1.  The client authenticates through Supabase Auth and receives a JWT.
2.  Next.js sends API requests to Express with `Authorization: Bearer <jwt>`.
3.  Express middleware validates the token, resolves tenant context, and executes domain logic through Drizzle against PostgreSQL.
4.  Public delivery remains read-optimized while media is served through CDN-backed assets.

---

## Architectural Principles

- Headless by design
- Structured content over raw HTML
- Control plane / data plane separation
- Stateless services
- Horizontal scalability
- Immutable content revisions
- Cloud-native deployment compatibility
- Multi-layer tenant isolation

---

## Technology Stack

Frontend (Control Plane):

- Next.js 15 (App Router)
- Tailwind CSS
- Shadcn/UI
- Hosted on Vercel

Backend (Data Plane):

- Node.js / Express (Render Free Tier)
- Zod validation

Database:

- PostgreSQL (Supabase)
- Drizzle ORM

Search:

- PostgreSQL Native FTS (tsvector)

Auth:

- Supabase Auth (JWT)
- Row Level Security (RLS)

Media:

- Cloudinary/UploadThing (auto-optimized CDN delivery)

Editor:

- Tiptap (headless)

---

## Project Structure (Conceptual)

packages/ admin-ui/ backend-core/ editor-engine/ page-builder/ sdk/
shared-types/

docs/ overview.md technical-architecture.md saas-blueprint.md
feature-blueprint.md sdk-blueprint.md

---

## Development Roadmap

Phase 1: - Multi-tenant core - Content CRUD - Public read API - Editor
integration

Phase 2: - Page builder engine - Media management - Versioning workflow

Phase 3: - Advanced billing models - Usage metering hardening - Feature
flags - SDK release

Phase 4: - Enterprise scaling - Observability enhancements - Performance
optimization - Plugin ecosystem

---

## Non-Functional Requirements

- Zero cross-tenant data leakage
- Deterministic API behavior
- Strong type contracts
- Observability-first deployment
- Rate limiting and security enforcement
- Immutable revision history
- CDN cache compatibility

---

## Security Model

- Role-Based Access Control (RBAC)
- Scoped API keys
- Provider-issued upload signature expiration
- Input validation
- Rate limiting
- Lifecycle-based tenant enforcement

---

## Scalability Strategy

- Stateless API services
- Horizontal scaling capability
- Connection pooling
- CDN-based caching
- Asynchronous usage metering
- Queue-ready background processing

---

## Documentation

This repository includes formal documentation covering:

- System Overview
- Technical Architecture Deep Dive
- Enterprise SaaS Blueprint
- Feature-Based System Design
- `CMS_Architecture_Decision_Matrix.md` (canonical source of truth)
- SDK Architecture Blueprint

---

## Engineering Maturity

This project demonstrates:

- Advanced multi-tenant system design
- SaaS control plane architecture
- Structured content modeling
- Scalable API strategy
- Production-ready SDK design
- Enterprise governance planning

It is intended as both a production-ready platform and a high-caliber
systems engineering showcase.

---

## License

Private / Proprietary (unless otherwise specified)

---

End of README
