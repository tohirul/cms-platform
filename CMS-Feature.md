# CMS Feature Parity Checklist

To replace WordPress entirely, the system must abstract content types, user permissions, and asset management into decoupled layers.

Here is the architectural guideline and checklist for achieving feature parity with WordPress.

---

## Phase 1: Core Architecture & Content Management

### 1. Custom Post Types (CPTs) & Taxonomies
A blog-only CMS maps data 1:1 with a "Posts" table. A WordPress replacement requires arbitrary content types (e.g., Portfolio items, Testimonials, Products) and custom categorization.

**Checklist:**
- [ ] Abstract database schema to support dynamic post_type identifiers.
- [ ] Implement a dynamic Taxonomy system (hierarchical like Categories, flat like Tags).
- [ ] Create UI builder for admins to register new CPTs without writing code.

**Implementation Guideline:**
Instead of isolated tables for every new data type, utilize a central `content_nodes` table paired with a `post_type` column. Leverage PostgreSQL's JSONB column capabilities to store dynamic attributes specific to each CPT, ensuring strong typing in TypeScript while maintaining database flexibility. Use standard relational mapping for taxonomies (terms, term_taxonomy, and term_relationships) to allow any content type to share categorization logic.

### 2. Block-Based Content Editor (Gutenberg Alternative)
Rich text editors (WYSIWYG) are insufficient for modern page building.

**Checklist:**
- [ ] Integrate a block-level editor (e.g., TipTap, Editor.js).
- [ ] Define schema for serializing block data into JSON.
- [ ] Build Next.js React components to dynamically render corresponding JSON blocks on the frontend.

**Implementation Guideline:**
Store content strictly as structured JSON rather than raw HTML. This ensures the Next.js frontend maintains total control over styling via Tailwind CSS and avoids XSS vulnerabilities. Map block types (e.g., `heading`, `image_gallery`, `code_snippet`) directly to highly optimized React server components.

---

## Phase 2: Asset & Media Management

### 3. Centralized Media Library
WordPress handles image processing, varied sizes, and metadata.

**Checklist:**
- [ ] Global media grid with drag-and-drop upload functionality.
- [ ] Asset metadata management (Alt text, captions, titles).
- [ ] API routes for handling multipart form data.

**Implementation Guideline:**
Implement an object storage solution (like AWS S3 or Cloudflare R2) integrated directly into the Next.js backend. Maintain an `assets` table in the database to index file URLs, MIME types, and alt text. Rely heavily on the Next.js `<Image />` component for on-the-fly format optimization (WebP/AVIF) and resizing, which eliminates the need to generate and store multiple physical image sizes upon upload as WordPress does.

---

## Phase 3: Administration & Workflows

### 4. Granular Role-Based Access Control (RBAC)
WordPress uses roles (Admin, Editor, Author, Contributor) mapped to specific capabilities.

**Checklist:**
- [ ] Define custom roles and a capabilities matrix (e.g., `edit_others_posts`, `publish_pages`).
- [ ] Implement middleware to protect API routes and Next.js admin layouts based on capabilities.
- [ ] Create an admin UI to manage users and assign permissions.

**Implementation Guideline:**
Use a JWT-based authentication flow. Store capabilities in a structured format in the database. In the Next.js `middleware.ts`, verify the user's role against the requested route's required capabilities before allowing request propagation.

### 5. Post Revisions, Autosaves & Content States
Content creators need to track changes and prevent data loss.

**Checklist:**
- [ ] Draft, Published, Scheduled, and Trashed post states.
- [ ] Autosave mechanism triggering background API `PUT` requests.
- [ ] Revisions table to diff and restore previous content versions.

**Implementation Guideline:**
Create a `content_revisions` table that stores snapshots of the `content_nodes` JSON payload. Implement debounced auto-saving on the client-side editor. For scheduled publishing, create a cron-job equivalent or leverage database triggers, coupled with Next.js On-Demand Revalidation (`revalidatePath` or `revalidateTag`) to instantly update the static cache when a scheduled post's time arrives.

---

## Phase 4: Configuration & SEO Optimization

### 6. Global Settings & Key-Value Options API
WordPress powers site-wide settings (Title, Tagline, Pagination limits) via the `wp_options` table.

**Checklist:**
- [ ] Centralized settings management panel.
- [ ] Navigation Menu builder (drag-and-drop hierarchy).

**Implementation Guideline:**
Create a highly indexed `options` table with `option_name` and `option_value` (JSONB). To ensure these global queries do not bottleneck page loads, leverage the Next.js Data Cache directly via isolated fetch requests with specific cache tags. Since an external memory store like Redis will not be utilized for this architecture, native Next.js caching combined with PostgreSQL materialized views handles configuration state efficiently.

### 7. Dynamic SEO & Meta Data Routing
A modern CMS must output perfect OpenGraph and schema.org markup.

**Checklist:**
- [ ] Custom meta title, description, and canonical URL overrides per post/page.
- [ ] Dynamic XML Sitemap generation.
- [ ] Automated Schema.org (JSON-LD) generation based on content type.

**Implementation Guideline:**
Utilize the Next.js App Router `generateMetadata` API. Fetch the dedicated SEO parameters from the content's JSONB metadata column and dynamically inject them into the server-rendered `<head>`. Create a dynamic `sitemap.xml/route.ts` that queries all published, public-facing content types.

---

## Phase 5: Extensibility & "Plugin" Architecture
WordPress's biggest advantage is its Action and Filter hook system, allowing third-party code to modify behavior without touching core files. Hardcoding every feature into a Next.js application defeats the purpose of a scalable CMS.

### 8. Event Hooks & Middleware Registry (The "Hooks" System)

**Checklist:**
- [ ] Implement an Event Emitter or Pub/Sub pattern in the Node.js backend for "Actions" (e.g., `onPostPublish`, `onUserRegister`).
- [ ] Implement a "Filter" registry allowing registered functions to intercept and modify data payloads before database execution or client rendering.
- [ ] Build a modular directory structure (e.g., `/plugins` or `/modules`) where isolated feature code can be dropped in and automatically registered on boot.

**Implementation Guideline:**
Create a core `HookRegistry` utility in TypeScript. When a request lifecycle runs, it should execute `applyFilters('content_output', contentData)`. This allows developers to build independent modules (like an SEO injector or a newsletter auto-poster) that register listeners to these hooks, replicating the WordPress `add_action` and `add_filter` paradigm perfectly.

---

## Phase 6: User Engagement & Community

### 9. Native Commenting & Moderation System
A blog/CMS needs community interaction, complete with spam protection and threading.

**Checklist:**
- [ ] Database schema for nested/threaded comments linked to specific content nodes.
- [ ] Admin dashboard for comment moderation (Approve, Spam, Trash).
- [ ] Honeypot or CAPTCHA integration to prevent automated bot spam.

**Implementation Guideline:**
Use PostgreSQL to handle threaded replies efficiently. Instead of a simple adjacency list (which requires expensive recursive queries), utilize an approach like Materialized Paths (storing a path string like `1/4/7` for nested replies) or PostgreSQL's native `LTREE` extension for ultra-fast querying of deep comment threads.

---

## Phase 7: Advanced Data Retrieval & Search

### 10. Full-Text Site Search
WordPress includes a native `?s=query` search, which is notoriously slow. A modern replacement must do better out-of-the-box.

**Checklist:**
- [ ] Implement a global search API endpoint.
- [ ] Configure search weighting (Title matches rank higher than body text matches).
- [ ] Build a frontend search UI with debounced auto-complete.

**Implementation Guideline:**
Leverage PostgreSQL's native Full Text Search capabilities. Create a `tsvector` column on your `content_nodes` table that automatically indexes the JSONB block content, titles, and excerpts. Use `tsquery` in your Next.js API routes to deliver highly performant, weighted search results without needing to provision external search engines or memory caches.

### 11. Multi-Language & Content Localization (i18n)
WordPress requires heavy plugins like WPML for this. A modern headless CMS should have localization natively.

**Checklist:**
- [ ] UI toggle in the block editor to switch between locales.
- [ ] Database architecture that links translated content nodes together.
- [ ] Sub-path routing in Next.js (e.g., `/en/blog` vs `/bn/blog`).

**Implementation Guideline:**
Instead of duplicating entire rows for translations, keep a single canonical `content_node`. Within the JSONB content column, store localized variants under locale keys (e.g., `{ "en": { "title": "..." }, "bn": { "title": "..." } }`). Combine this with Next.js App Router's native `[lang]` dynamic segment routing to serve the correct data based on the URL.

---

## Phase 8: Interactivity & Leads

### 12. Dynamic Form Builder
WordPress relies on plugins like Contact Form 7 or Gravity Forms to capture user input. A complete CMS needs native form handling.

**Checklist:**
- [ ] Drag-and-drop form builder in the admin panel (Text inputs, dropdowns, radio buttons).
- [ ] Secure API endpoint specifically for handling dynamic form submissions.
- [ ] Submissions database table and an admin UI to view/export collected lead data (CSV).

**Implementation Guideline:**
Treat forms as a specialized Custom Post Type. The "content" of the form is a JSON schema defining the fields. When a frontend user submits the form, the Next.js server action validates the payload against the JSON schema stored in the database, sanitizes the inputs, and saves it to a `form_submissions` table.

---

## Phase 9: Deployment & Maintenance

### 13. Database Migrations & Backup GUI
WordPress handles structural updates transparently and offers simple export tools.

**Checklist:**
- [ ] Automated schema migration runner for structural updates.
- [ ] One-click JSON/CSV export tool for all content, users, and media metadata.

**Implementation Guideline:**
Use an ORM or query builder (like Drizzle or Prisma) to maintain a strict version history of the database schema. Implement a backend utility that streams database rows into a downloadable JSON file, ensuring administrators never feel "locked in" to the custom CMS platform.

---

## Phase 10: Background Processing & Task Scheduling (WP-Cron Alternative)
WordPress relies on WP-Cron, a "virtual" cron system triggered by site visitors, which can cause severe performance spikes and missed schedules. A professional CMS requires a reliable, decoupled background worker system for tasks like sending batch emails, generating reports, or hitting external webhooks.

### 14. Database-Backed Job Queue

**Checklist:**
- [ ] Create a `job_queue` table in PostgreSQL to track pending, running, and failed tasks.
- [ ] Implement a Node.js worker process that polls the table.
- [ ] Build an admin dashboard for observing job statuses and retrying failed tasks.

**Implementation Guideline:**
Because relying on an external in-memory datastore is unnecessary and adds infrastructure overhead, implement a robust PostgreSQL-backed job queue. Utilize `SQL FOR UPDATE SKIP LOCKED` queries to allow multiple Node.js worker threads to safely pop jobs off the queue concurrently without race conditions. This keeps the entire background processing ecosystem cleanly contained within the primary database.

---

## Phase 11: Content Syndication & Headless Distribution
WordPress automatically generates RSS feeds, Atom feeds, and a fully discoverable REST API (`/wp-json/`) out of the box. Your platform must allow external services (like Apple News, Flipboard, or email marketing tools) to consume its content seamlessly.

### 15. RSS & Atom Feed Generation

**Checklist:**
- [ ] Dynamic XML generation for `/feed.xml` and `/rss.xml`.
- [ ] Custom feed endpoints for specific categories or Custom Post Types.

**Implementation Guideline:**
Create a Next.js Route Handler (`app/feed/route.ts`) that queries the most recent public `content_nodes`. Use a package like `rss` or build a pure XML string builder to map your JSONB content blocks into standard HTML for feed readers, caching the output heavily using Next.js revalidate timers to minimize database hits.

### 16. Public Headless API

**Checklist:**
- [ ] Read-only REST or GraphQL API endpoints for all public content.
- [ ] API key generation and rate-limiting middleware for third-party consumers.

---

## Phase 12: Advanced Media Manipulation
Uploading media is Phase 2, but WordPress also allows non-technical users to edit those images directly within the browser (scaling, cropping, rotating) without needing external software like Photoshop.

### 17. In-Browser Image Editor

**Checklist:**
- [ ] Integrate a canvas-based frontend cropping/rotation tool (e.g., `react-image-crop`).
- [ ] Backend endpoint to process and overwrite the physical file via Node.js streams.
- [ ] "Restore Original" feature.

**Implementation Guideline:**
When an admin modifies an image in the Next.js frontend, send the crop coordinates (x, y, width, height) and rotation degrees to the server. Use a high-performance image processing library like `sharp` in your Node.js backend to apply the transformations, update the object storage, and invalidate the previous image's CDN cache. Store a reference to the original, unmodified file in the `assets` table to allow reversible edits.

---

## Phase 13: Multisite / Multi-Tenant Network (Optional but Powerful)
WordPress Multisite allows a single codebase and database to power hundreds of separate websites, each with their own domains, users, and settings.

### 18. Network Architecture (Multi-Tenant)

**Checklist:**
- [ ] Add a `tenant_id` or `site_id` column to all critical database tables (`content_nodes`, `users`, `options`, `assets`).
- [ ] Domain mapping middleware to detect the incoming host header and scope database queries to the correct site.
- [ ] "Super Admin" role capable of managing the entire network, vs. "Site Admin" for individual domains.

**Implementation Guideline:**
Utilize Next.js Middleware to intercept the incoming request and read the `Host` header. Look up the domain in a `sites` table to determine the `site_id`, then rewrite the URL to a dynamic segment (e.g., `/[site_id]/blog/my-post`). Ensure your backend query architecture strictly enforces Row-Level Security (RLS) in PostgreSQL, automatically scoping all data retrieval to the current `site_id` to prevent cross-tenant data leaks.

---

## Phase 14: Full Site Editing (FSE) & Dynamic Templating

### 19. Template & Template-Part Management

**Checklist:**
- [ ] Create a specialized Custom Post Type for "Templates" (e.g., Single Post layout, 404 page, Category Archive) and "Template Parts" (Headers, Footers).
- [ ] Implement a `theme.json` equivalent stored in the database to control global design tokens (primary colors, typography scales, spacing).
- [ ] Frontend routing override: Next.js must check if a database template exists for the current route before falling back to a hardcoded `page.tsx`.

**Implementation Guideline:**
Store layouts as an array of JSON blocks. In your Next.js `app/layout.tsx`, fetch the "Header" and "Footer" template parts from PostgreSQL. When rendering a `/blog/[slug]` route, fetch the "Single Post" template layout, and inject the specific post's title and content blocks dynamically into that layout's designated placeholder blocks.

---

## Phase 15: Security, Auditing & Compliance
For a CMS to replace WordPress in corporate or high-stakes environments, simply having RBAC (Role-Based Access Control) isn't enough. System administrators need complete visibility into what happens inside the platform.

### 20. Comprehensive Activity Audit Trail

**Checklist:**
- [ ] Centralized `audit_logs` database table.
- [ ] Middleware/Event interceptor to log critical actions (User logins, role changes, content publications, settings modifications).
- [ ] Admin UI to filter logs by user, date, and action type.

**Implementation Guideline:**
Tie this into the Hook/Event system created in Phase 5. Whenever an update or insert action occurs via your API, trigger a non-blocking asynchronous function that writes to the `audit_logs` table. Include the `user_id`, the `resource_id` (e.g., Post ID 142), the action ("published"), and a JSON diff payload showing exactly what changed from the previous state.

### 21. Advanced Authentication & Rate Limiting

**Checklist:**
- [ ] Implement Two-Factor Authentication (2FA/MFA) using TOTP (Authenticator apps).
- [ ] API rate limiting to prevent brute-force attacks on login and password reset routes.
- [ ] Session invalidation (force logout across all devices).

---

## Phase 16: The "WooCommerce" Factor (Monetization Readiness)
While WordPress started as a blog, an enormous percentage of its market share exists because it acts as a foundational layer for e-commerce via WooCommerce. Even if you aren't building a store today, the architecture must support transactional relationships.

### 22. Transactional Data & Protected Content

**Checklist:**
- [ ] Establish a `users_meta` table (or robust JSONB column on the `users` table) to store shipping/billing profiles, Stripe Customer IDs, etc.
- [ ] Content gating logic: Ability to flag specific content nodes as "Premium" or requiring a specific user capability/subscription to view.
- [ ] Webhook ingestion endpoints (e.g., listening for Stripe/PayPal payment success events to automatically upgrade a user role).

**Implementation Guideline:**
Do not build a full shopping cart from scratch initially. Instead, ensure your CPT and Hook architecture allows a future "Store Module" to register new data types (Products, Orders, Coupons). Build Next.js server actions that validate a user's session against a `subscriptions` table before rendering the full JSON block payload to the client, effectively creating a hard paywall.

---

## Phase 17: Admin Dashboard & Analytics Widgets
The first thing a WordPress user sees upon login is the Dashboard—a customizable grid of widgets showing site health, recent comments, and traffic summaries.

### 23. Pluggable Dashboard Engine

**Checklist:**
- [ ] Drag-and-drop grid system for the admin home screen.
- [ ] Widget API allowing internal modules (or future plugins) to register their own summary cards.
- [ ] Basic native analytics tracking (page views stored via background queues to avoid slowing down rendering) or seamless integration with Google Analytics 4/Plausible via global settings.

---

## Phase 18: Advanced Caching & Live Previews
WordPress relies on heavily configured plugins (like WP Rocket or W3 Total Cache) to generate static HTML and bypass the database. Since this architecture uses Next.js, caching is native, but it introduces the complex problem of "Headless Previews" and granular cache invalidation.

### 24. Next.js Draft Mode & Headless Previews

**Checklist:**
- [ ] Implement Next.js Draft Mode via a secure API route (`/api/draft`).
- [ ] Create a "Live Preview" iframe split-screen in the admin editor.
- [ ] Ensure draft queries bypass the Next.js Data Cache to show real-time unsaved changes.

**Implementation Guideline:**
When a user clicks "Preview" in your block editor, generate a temporary cryptographic token. Redirect an iframe to your Next.js frontend with this token (e.g., `/?draft=token`). The Next.js backend intercepts this, enables `draftMode()`, and queries the `content_revisions` table or the autosaved JSON payload instead of the published `content_nodes` data, providing a perfect 1:1 preview of the unpublished content.

### 25. Cache Invalidation Engine

**Checklist:**
- [ ] Database triggers or Node.js hooks to detect content updates.
- [ ] Targeted Next.js `revalidateTag` execution.
- [ ] Admin UI "Clear Cache" utility for manual CDN purging.

**Implementation Guideline:**
Tag all frontend Next.js fetch requests with specific identifiers (e.g., `fetch(url, { next: { tags: ['posts', `post-${id}`] } })`). When a post is updated in the CMS, invoke a webhook to the frontend that triggers `revalidateTag('post-142')` and `revalidateTag('posts')`. This ensures instant updates for that specific post and the blog index, without needing an external memory store to manage cache states.

---

## Phase 19: Automation & Outbound Interoperability
Modern platforms don't just sit in isolation; they push data to other services. WordPress does this via heavy plugins. A modern platform should have a native webhook dispatch system.

### 26. Outbound Webhook Manager

**Checklist:**
- [ ] Create a `webhooks` database table (URL, Events to listen for, Secret Keys).
- [ ] Admin UI to register endpoints (e.g., sending a payload to Zapier/Make, Discord, or triggering a Vercel deployment).
- [ ] Asynchronous dispatch system to prevent webhook failures from blocking the main request thread.

**Implementation Guideline:**
Tie this into the Action Hooks created in Phase 5. If a user registers a webhook for the `post_published` event, your Node.js backend pushes a job to the PostgreSQL job queue (from Phase 10). A background worker then processes the HTTP POST request to the external URL. This guarantees that if the receiving server is down, your CMS doesn't crash or hang while waiting for a response.

---

## Phase 20: System Health & Maintenance
WordPress has the "Site Health" screen, which runs diagnostics on the server environment. Your CMS needs a way to self-diagnose and report issues to the administrator.

### 27. Diagnostic & System Health Dashboard

**Checklist:**
- [ ] Monitor PostgreSQL connection pool health and database size.
- [ ] Monitor available storage space in the object storage (S3/R2) bucket.
- [ ] Check for orphaned files (media in storage with no database reference) and provide a one-click cleanup tool.

---

## Phase 21: The "On-Ramp" (Data Importers)
If you are building a replacement for WordPress, your biggest hurdle is getting users to migrate away from WordPress. You must build an automated bridge.

### 28. Native WordPress WXR Importer

**Checklist:**
- [ ] XML parser capable of reading WordPress eXtended RSS (WXR) files.
- [ ] Migration script to map WordPress `wp_posts` and `postmeta` to your new JSONB `content_nodes` schema.
- [ ] Automated asset scraper that downloads images from the old WordPress URLs, uploads them to your object storage, and rewrites the URLs inside the imported content.

**Implementation Guideline:**
Treat the import process as a background queue job, as parsing a 50MB XML file from a 10-year-old WordPress blog will time out a standard HTTP request. Stream the XML file upload to the server, chunk it into individual posts, and insert them into your database iteratively, reporting real-time progress via Server-Sent Events (SSE) or WebSockets back to the admin UI.

---

## Phase 22: Rich Media Parsing (The oEmbed Engine)
In WordPress, a user can paste a plain YouTube, Twitter (X), or Spotify URL on its own line in the editor, and the CMS automatically transforms it into a rich iframe embed on the frontend.

### 29. Native oEmbed Resolution

**Checklist:**
- [ ] Create a registry of trusted oEmbed providers (YouTube, Vimeo, Twitter, etc.).
- [ ] Build a background parser that detects raw URLs in the text blocks.
- [ ] Implement an API endpoint that fetches the external provider's oEmbed JSON endpoint and caches the resulting HTML iframe structure in your database.

**Implementation Guideline:**
Do not force the Next.js frontend to resolve these URLs on every page load; this will severely impact Core Web Vitals. Instead, when the author saves the post, have the backend intercept the raw URL block, query the provider, and swap the raw URL in the database's JSON payload with the fully resolved HTML/iframe data.

---

## Phase 23: Inline Dynamic Components (Shortcode API)
WordPress uses the `[shortcode]` syntax to allow non-technical users to inject complex PHP functions (like contact forms, pricing tables, or dynamic user data) into the middle of standard text paragraphs.

### 30. AST Parsing & Token Replacement

**Checklist:**
- [ ] Define a syntax for inline tokens (e.g., `{{ form:contact_id }}`).
- [ ] Build a server-side parser that reads the JSON block content and identifies these tokens.
- [ ] Create an injection engine to swap tokens with React Server Components.

**Implementation Guideline:**
While a block editor handles macro-level layout, inline text often needs dynamic data. Use a tool like `html-react-parser` or build a custom Abstract Syntax Tree (AST) parser in your Next.js render cycle. When it detects a registered token in the text string, it suspends, fetches the necessary data, and swaps the string token for a compiled Next.js component before shipping the HTML to the client.

---

## Phase 24: Communications Abstraction (wp_mail)
WordPress routes all system emails (password resets, new user welcomes, comment notifications) through a single function: `wp_mail()`. This allows plugins to easily intercept and format emails, or reroute them through services like SendGrid.

### 31. Pluggable Email Engine

**Checklist:**
- [ ] Create a core utility function (e.g., `cms.sendEmail()`) that all other modules must use.
- [ ] Implement an "Adapter" pattern allowing the admin to switch the underlying email provider (SMTP, AWS SES, Resend) from the UI without changing code.
- [ ] Integrate a templating engine (like React Email) for generating responsive HTML emails.

**Implementation Guideline:**
Never hardcode `nodemailer` calls directly into your API routes. Route all email requests through your `HookRegistry` (from Phase 5). This allows a developer to write a custom module that "hooks" into the email payload, injects a custom branded header/footer template, and then passes it to the selected provider adapter.

---

## Phase 25: Asset Encapsulation (The Enqueue API)
When a WordPress plugin needs to add a JavaScript file or a CSS stylesheet to the frontend, it uses `wp_enqueue_script()`. This prevents conflicts, handles dependencies (e.g., "don't load my script until React is loaded"), and ensures assets only load on pages where they are needed.

### 32. Modular Asset Injection

**Checklist:**
- [ ] Build a context provider or server-side store that modules can push asset paths into during the request lifecycle.
- [ ] Modify the Next.js root `layout.tsx` to read this store and dynamically output `<link>` and `<script>` tags just before the `</body>` tag.

**Implementation Guideline:**
In a standard Next.js app, you import CSS and JS directly into components. But in a highly modular CMS where third-party developers might drop "plugins" into a folder, those plugins need a safe way to inject their specific styles into the global build. You must create an API that allows a module to say, "If the current route is a Single Post, enqueue this specific CSS file," without modifying the core Next.js source code.

---

## Phase 26: State Synchronization & Session Management
WordPress prevents data corruption when multiple authors are working simultaneously and ensures the browser is constantly aware of the server's state.

### 33. Real-Time Sync (The Heartbeat API Alternative)

**Checklist:**
- [ ] Implement a background polling mechanism or Server-Sent Events (SSE) connection in the admin dashboard.
- [ ] Build "Post Locking" functionality to warn User B that User A is currently editing the content.
- [ ] Implement session expiration warnings (prompting the user to log back in via a modal without losing their unsaved changes).

**Implementation Guideline:**
Create a lightweight `api/heartbeat` endpoint that the admin frontend pings every 15-60 seconds. This endpoint should check the user's authentication token validity and query an `active_locks` table to ensure no two authors overwrite each other's block JSON data.

### 34. Application Passwords (Remote Publishing)

**Checklist:**
- [ ] Create an admin UI for users to generate unique, easily revokable API tokens.
- [ ] Implement basic auth or bearer token middleware specifically for the REST API.

**Implementation Guideline:**
If you want your CMS to be compatible with external mobile apps or desktop publishing tools (similar to how the official WordPress mobile app works), the standard web session cookie won't work. Generate scoped tokens that belong to a user but can only be used for external API requests, not logging into the visual dashboard.

---

## Phase 27: Granular Data Caching
You already have full-page caching via Next.js, but your custom backend logic will sometimes need to cache complex database queries or expensive third-party API responses for a specific duration. WordPress handles this via the Transients API.

### 35. Expiring Key-Value Store (Transients API Alternative)

**Checklist:**
- [ ] Create a `transients` database table with `key`, `value` (JSONB), and `expiration_time` columns.
- [ ] Write helper functions (e.g., `setTransient`, `getTransient`) that automatically check the expiration time before returning the data.

**Implementation Guideline:**
Since the architecture will avoid the use of external memory stores like Redis, handle this directly within PostgreSQL. When `getTransient('github_repo_stats')` is called, check if the current timestamp is past `expiration_time`. If it is, delete the row, make the slow API call, and insert the fresh data. You can run a background cron job (from Phase 10) to periodically clean up expired rows.

---

## Phase 28: System-Level Execution
Standard plugins or modules can be deactivated by site administrators. However, enterprise CMS environments often require underlying code that cannot be touched by the end-user. WordPress handles this via Must-Use Plugins (mu-plugins).

### 36. Immutable Boot Modules (mu-plugins Alternative)

**Checklist:**
- [ ] Create a dedicated `/system-modules` directory in your Node.js backend.
- [ ] Modify the application boot sequence to auto-require and execute every script in this folder before loading the standard module registry.

**Implementation Guideline:**
This is critical for a multi-tenant or managed hosting environment. If you need to enforce a specific security policy, force a connection to an external logging service, or permanently disable certain CPTs across the network, this code must run before the database is even queried for standard user settings.

---

## Phase 29: Routing & URL Abstraction

### 37. The Rewrite Rules Engine (Custom Permalinks)
WordPress allows administrators to globally change the URL structure of the site without touching code (e.g., switching from `/post-name/` to `/%year%/%monthnum%/%postname%/`). Next.js App Router relies on strict file-system routing (like `app/[slug]/page.tsx`), making dynamic global route structures difficult natively.

**Checklist:**
- [ ] Create a `rewrite_rules` registry in the database.
- [ ] Implement a Next.js Middleware interceptor that decodes custom URL structures, looks up the corresponding `post_id`, and rewrites the request to a hidden, standardized Next.js dynamic route under the hood.

---

## Phase 30: Content Architecture

### 38. Synced Patterns (Reusable Blocks)
Gutenberg allows users to design a complex block (like a specific Call-To-Action banner), save it, and place it on 50 different pages. Editing the original block updates it across all 50 pages instantly.

**Checklist:**
- [ ] Register a specific system-level Custom Post Type for `wp_block` (or `reusable_blocks`).
- [ ] When the AST parser or Next.js React component encounters a block with type `reference` and an `ID`, fetch that specific block's JSON payload from the `content_nodes` table and render it inline.

---

## Phase 31: Data Hygiene & Maintenance

### 39. Automated Garbage Collection (Trash Management)
In Phase 3, you implemented "Trashed" post states. However, WordPress natively prevents database bloat by automatically permanently deleting trashed posts and spam comments after 30 days.

**Checklist:**
- [ ] Create a scheduled job for the Node.js background worker queue (from Phase 10) that runs daily.
- [ ] Execute a PostgreSQL query to permanently `DELETE` rows where `status = 'trash'` and `updated_at` is older than 30 days, ensuring the corresponding object storage assets are also purged to save costs.

---

## Phase 32: User & Profile Management

### 40. User Profiles & Avatar Integration
While RBAC and authentication are covered, WordPress natively handles public author profiles and integrates seamlessly with Gravatar for profile pictures across the ecosystem.

**Checklist:**
- [ ] Extend the user admin UI to handle biographical info, social links, and display name preferences.
- [ ] Create a helper utility that hashes the user's email address and fetches their global avatar from Gravatar (or a self-hosted fallback) if no custom profile picture is uploaded to the Next.js media library.
