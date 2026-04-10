# TikTokSlop — Master Build Plan

A multi-tenant Rails 8 application for automating TikTok Shop affiliate outreach,
creator discovery, targeted collaborations, and sample fulfillment. Built as a
proper SaaS from day one, deployable for personal use first and for external
customers later.

**Repo**: `github.com/Fladdermuz/TikTokSlop`
**Stack**: Rails 8.1 / Ruby 3.3.6 / Postgres 17 (dev) / Postgres 16 (prod) / Hotwire / Tailwind / Solid Queue
**Production domain**: `tikedon.com` (Cloudflare → 146.190.139.89)
**Server**: `ssh repify` (same physical host as `ssh bionox` — Ubuntu 24.04)
**Deploy method**: Apache + Phusion Passenger (matches existing Repify.me pattern)

---

## Table of contents

- [Guiding principles](#guiding-principles)
- [Architecture overview](#architecture-overview)
- [Phase status](#phase-status)
- [Phase 0 — Foundation](#phase-0--foundation-done)
- [Phase 1 — Multi-tenant foundation](#phase-1--multi-tenant-foundation)
- [Phase 2 — TikTok Shop API client](#phase-2--tiktok-shop-api-client)
- [Phase 3 — OAuth (per-shop connection)](#phase-3--oauth-per-shop-connection)
- [Phase 4 — Creator discovery](#phase-4--creator-discovery)
- [Phase 5 — Campaign management](#phase-5--campaign-management)
- [Phase 6 — Bulk invite engine](#phase-6--bulk-invite-engine)
- [Phase 7 — Sample fulfillment](#phase-7--sample-fulfillment)
- [Phase 8 — Performance & analytics](#phase-8--performance--analytics)
- [Phase 9 — Shop-level user management UI](#phase-9--shop-level-user-management-ui)
- [Phase 10 — Platform admin console](#phase-10--platform-admin-console)
- [Phase 11 — Production hardening](#phase-11--production-hardening)
- [Phase 12 — Deploy to bionox server](#phase-12--deploy-to-bionox-server)
- [Phase 13 — Post-launch (optional)](#phase-13--post-launch-optional)
- [Cross-cutting concerns](#cross-cutting-concerns)
- [Open questions](#open-questions)
- [Blocker log](#blocker-log)

---

## Server co-tenancy — DO NOT BREAK

The production server (`ssh repify` = `ssh bionox` = `146.190.139.89`) hosts **two other apps** we must not disturb. Read this section before any deploy work.

### Existing apps on this host

| App | Type | Ruby | Web tier | Path | Port | Users |
|---|---|---|---|---|---|---|
| **Repify.me** | Rails 7.2.1 | 3.3.6 (RVM) | **Apache + Passenger** | `/var/www/Repify.me` | via Passenger | `prod_user_9988:www-data` |
| **bionox.info** | Next.js | (N/A) | **Apache ProxyPass → Puma-free** | `/var/www/bionox.info` | localhost:**3001** (PM2) | `prod_user_9988` |

### Environment

- **OS**: Ubuntu 24.04.1 LTS (noble)
- **Apache**: 2.4.58 with `libapache2-mod-passenger` 6.0.25
- **Passenger default Ruby**: `/usr/bin/ruby3.2` (Ubuntu system Ruby 3.2.3) — **don't rely on this**, always override `PassengerRuby` per vhost
- **Ruby 3.3.6**: available via system-wide RVM at `/usr/local/rvm/gems/ruby-3.3.6/wrappers/ruby`
- **Postgres**: 16, localhost:5432. DBs `repify_dev`, `repify_me`, `repify_prod` — all owned by `prod_user_9988`
- **Redis**: 6379 localhost (used by Repify.me Sidekiq) — available if we want it but not planned
- **PM2**: runs under `prod_user_9988` — currently only the `bionox` Next.js process
- **Deploy user**: `prod_user_9988` owns `/var/www/*` (except Repify.me which is owned by same but has `www-data` group)
- **Uptime**: 349 days — no reboots without explicit reason
- **SSH**: root access works via `ssh repify`. Git + SSH keys already set up for deploy.

### Existing Apache vhosts (do not modify)

```
/etc/apache2/sites-enabled/
  ├── 000-default.conf              → repify.me (HTTP)
  ├── 000-default-le-ssl.conf       → repify.me (HTTPS, Let's Encrypt)
  ├── bionox.info.conf              → bionox.info (HTTP → 127.0.0.1:3001)
  └── bionox.info-ssl.conf          → bionox.info (HTTPS → 127.0.0.1:3001)
```

Note: `000-default.conf` is **mis-named** — despite the default-sounding name it's the Repify.me vhost. Don't be tempted to "fix" it.

### What we will add for tikedon.com (and nothing else)

- New directory: `/var/www/tikedon.com` owned `prod_user_9988:www-data`
- New Postgres DB: `tikedon_production` (owner to be decided — likely `prod_user_9988` for consistency, or a dedicated `tikedon` user for least privilege)
- New Apache vhosts: `/etc/apache2/sites-available/tikedon.com.conf` + `tikedon.com-ssl.conf`, symlinked into `sites-enabled`
- New systemd service: `tikedon-jobs.service` for Solid Queue worker (or `pm2` process under `prod_user_9988` — pick one at Phase 12)
- New Let's Encrypt cert: `certbot --apache -d tikedon.com -d www.tikedon.com` (Cloudflare set to DNS-only on tikedon.com during issuance, or use DNS-01 challenge)
- `tikedon.com` DNS A record on Cloudflare → `146.190.139.89` (already set)

### What we will NOT do

- Modify Repify.me's vhost, code, database, or RVM gemset
- Modify bionox.info's vhost, PM2 process, or Next.js build
- Upgrade Ruby, Apache, Passenger, or Postgres system-wide
- Restart services that aren't ours
- Take port 3001 (bionox.info) or Redis 6379 (leave for Repify.me unless explicitly chosen)
- Run `apt upgrade`, `rvm cleanup`, or anything system-wide without asking
- Share a Postgres role with Repify.me (new DB, new or existing role, but not a shared DB)

---

## Guiding principles

1. **Multi-tenant from day one.** Retrofitting tenancy later is 2–3x the cost of building it in now.
2. **Rails conventions, minimal new dependencies.** Use Hotwire, Solid Queue, Solid Cache, and built-in Rails 8 auth — no BullMQ, no Redis, no React, no NextAuth.
3. **Encrypted secrets at rest.** OAuth tokens and anything API-sensitive uses `encrypts`.
4. **Strict tenant isolation.** Every query that touches shop-scoped data must go through `Current.shop` or an explicit scope. No accidental cross-tenant reads.
5. **Background jobs respect TikTok rate limits.** Bulk actions queue through Solid Queue with per-shop rate limiting. Never hammer the API.
6. **Observability before deploy.** Structured logs, error tracking, health checks — all in place before `slop.bionox.info` goes live.
7. **Tests for tenancy, OAuth, and the API client.** Lower priority: pixel-perfect UI tests. Tenant leakage is the only bug we cannot ship with.
8. **Commit often, small logical commits.** Each phase is a series of commits, not one giant PR.

---

## Architecture overview

```
┌──────────────────────────────────────────────────────────────────┐
│  Web tier (Puma)                                                  │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │  Controllers + Hotwire views                              │    │
│  │  - SessionsController  (login/logout)                     │    │
│  │  - Shops::*            (scoped under current shop)        │    │
│  │  - Admin::*            (platform admin only)              │    │
│  │  - Tiktok::OauthController  (connect callback)            │    │
│  └──────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  Service layer                                                    │
│                                                                    │
│  - Tiktok::Client            (Faraday + signing + retry)         │
│  - Tiktok::Oauth             (state, code exchange, refresh)     │
│  - Tiktok::CreatorSearch     (search + cache write-through)      │
│  - Tiktok::InviteSender      (targeted collaboration)            │
│  - Tiktok::SampleOrder       (sample offers)                     │
│  - Shop::Context             (Current.shop resolver)             │
│  - Shop::Authorization       (policy checks)                     │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  Persistence (Postgres 17)                                        │
│                                                                    │
│  Global:  users, sessions, shops, memberships, creators          │
│  Scoped:  tiktok_tokens, campaigns, invites, samples              │
│  System:  solid_queue_*, solid_cache_*, solid_cable_*            │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  Background workers (Solid Queue via bin/jobs)                    │
│                                                                    │
│  - Tiktok::RefreshTokenJob           (recurring, per shop)        │
│  - Tiktok::BulkInviteJob             (enqueue per-invite jobs)    │
│  - Tiktok::SendInviteJob             (one creator, rate-limited)  │
│  - Tiktok::SyncInviteStatusJob       (poll pending invites)       │
│  - Tiktok::SyncSampleStatusJob       (poll pending samples)       │
│  - Tiktok::ImportShopCatalogJob      (sync products once)         │
└──────────────────────────────────────────────────────────────────┘
```

**Tenancy model**
- `User` and `Session` are global; a user can belong to many shops.
- `Shop` is a tenant boundary. It owns its `TiktokToken`, campaigns, invites, samples.
- `Membership` joins `User` ↔ `Shop` with a role (`owner`, `admin`, `member`).
- `Creator` is **global** — cached TikTok data shared across tenants. Only relational data (invites, samples) is per-shop.
- `Current.user`, `Current.shop`, and `Current.membership` are set per request via a before-action.

**Role hierarchy**
- `User#platform_admin?` — global flag, bypasses all shop scoping. Reserved for you.
- `Membership#owner` — one per shop at creation, can delete the shop and transfer ownership.
- `Membership#admin` — can invite/remove users, connect TikTok, change shop settings.
- `Membership#member` — can run campaigns, send invites, manage samples. No shop config.

---

## Phase status

| Phase | Name | Status |
|-------|------|--------|
| 0 | Foundation | ✅ done |
| 1 | Multi-tenant foundation | ⏸ pending |
| 2 | TikTok Shop API client | ⏸ pending |
| 3 | OAuth flow (per-shop) | ⏸ pending (blocked on TikTok app approval) |
| 4 | Creator discovery | ⏸ pending |
| 4.5 | Message moderation pipeline (banned-keyword + AI) | ⏸ pending |
| 5 | Campaign management | ⏸ pending |
| 5.5 | Product knowledge base + AI message crafter | ⏸ pending |
| 6 | Bulk invite engine | ⏸ pending |
| 7 | Sample fulfillment | ⏸ pending |
| 8 | Performance & analytics | ⏸ pending |
| 9 | Shop-level user management UI | ⏸ pending |
| 10 | Platform admin console | ⏸ pending |
| 11 | Production hardening | ⏸ pending |
| 12 | Deploy to bionox server | ⏸ pending |
| 13 | Post-launch (optional) | ⏸ pending |

---

## Phase 0 — Foundation (done)

Already on disk. First commit: `Initial Rails 8 scaffold with core schema`.

**Done**
- Rails 8.1.3 app with Postgres, Tailwind, Hotwire, Solid Queue/Cache/Cable
- `bcrypt`, `faraday`, `faraday-retry` gems added
- `pg` gem rebuilt against Postgres 17
- Development + test databases created
- Initial models: `Creator`, `Campaign`, `Invite`, `Sample`, `TiktokToken`
- Rails encryption keys configured in credentials
- End-to-end encryption verified (tokens encrypt at rest)

**Will be modified in Phase 1**
- `TiktokToken`, `Campaign`, `Invite`, `Sample` get a `shop_id` column
- `Creator` stays global (no `shop_id`)

---

## Phase 1 — Multi-tenant foundation

**Goal**: Every user logs in. Every query is scoped to the current shop. No accidental cross-tenant leaks.

### 1.1 Rails 8 built-in authentication
- Run `bin/rails generate authentication` — creates `User`, `Session`, `SessionsController`, `PasswordsController`, `Authentication` concern
- Add `platform_admin:boolean` to `User` with `default: false, null: false`
- Add `name:string` to `User`

### 1.2 Shop + Membership models
- `Shop`: `name`, `slug` (for URLs), `plan` (string, default `"free"`), `timezone`, `status`
- `Membership`: `user:references`, `shop:references`, `role:string`, `invited_at`, `joined_at`
- Unique index on `(user_id, shop_id)`
- Unique index on `shops.slug`
- Each Shop must have at least one `owner` membership
- `Shop` has_many `users` through `memberships`
- `User` has_many `shops` through `memberships`

### 1.3 Scope existing tenant tables
Migration to add `shop_id` (null: false, foreign key) to:
- `tiktok_tokens` (change uniqueness: unique on `(shop_id)` — one TikTok connection per shop)
- `campaigns`
- `invites`
- `samples` (redundant with `invite.shop_id` but denormalized for query speed)

Drop the existing `shop_id` unique index on `tiktok_tokens.shop_id` from Phase 0 and redo as FK + unique.

### 1.4 `Current` attributes
```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :session, :user, :membership, :shop
  delegate :platform_admin?, to: :user, allow_nil: true
end
```

### 1.5 Shop context middleware / before_action
- On every authenticated request, resolve `Current.shop` from either:
  1. URL param `:shop_slug` (explicit routes)
  2. Session `current_shop_id` (implicit)
  3. Default to user's first shop if unset
- If user has no shops, redirect to `/shops/new` (or `/no_access` for non-admins)

### 1.6 `ShopScoped` concern
```ruby
# app/models/concerns/shop_scoped.rb
module ShopScoped
  extend ActiveSupport::Concern
  included do
    belongs_to :shop
    default_scope { where(shop: Current.shop) if Current.shop }
  end
end
```
Apply to: `TiktokToken`, `Campaign`, `Invite`, `Sample`.
(`Creator` is NOT scoped — it's global.)

> **Caveat on default_scope**: dangerous if misused. An alternative is explicit `.for_shop(Current.shop)` scopes. We'll use `default_scope` with tests that assert tenant isolation, and `unscoped` where we need cross-tenant queries (platform admin).

### 1.7 Routes
```ruby
# config/routes.rb
resource :session
resources :passwords, param: :token
root "dashboard#show"

resources :shops, only: %i[index new create] do
  member do
    post :switch
  end
end

# Everything below operates under Current.shop
namespace :shop do
  resource :dashboard, only: :show
  resources :creators, only: %i[index show]
  resources :campaigns
  resources :invites, only: %i[index show]
  resources :samples, only: %i[index show]
  resource :tiktok_connection, only: %i[show destroy]
  resources :members, only: %i[index new create destroy]
end

namespace :tiktok do
  get  :callback, to: "oauth#callback"
end

namespace :admin do
  resource :dashboard, only: :show
  resources :shops
  resources :users
end
```

### 1.8 Login / navigation UI
- Login page (styled with Tailwind)
- Top nav with user menu, current shop indicator, shop switcher dropdown
- Logout
- Placeholder dashboards (empty states)

### 1.9 Policy layer (hand-rolled, no gem)
```ruby
# app/policies/application_policy.rb
class ApplicationPolicy
  attr_reader :user, :membership, :record
  def initialize(user:, membership:, record:)
    @user, @membership, @record = user, membership, record
  end

  def platform_admin? = user&.platform_admin?
  def shop_admin?    = membership&.role&.in?(%w[owner admin])
  def shop_member?   = membership&.role&.in?(%w[owner admin member])
end
```
One policy class per resource. Controllers call `authorize!(:edit, @campaign)`.

### 1.10 Tenant isolation tests
- Create two shops, two users, assert that user A cannot query shop B's campaigns
- Test the `ShopScoped` default scope under every condition (direct query, `includes`, `joins`, background job)
- Test that platform admin can bypass via `unscoped` but normal user cannot

**Deliverables**
- Working login → dashboard flow
- `bin/rails runner` seed that creates a platform admin + one shop + membership
- Test suite passes with tenant isolation tests green
- Commit per sub-step (auth gen / shop models / scoping / routes / policies / tests)

**Dependencies**: none (Phase 0 complete).
**Estimated commits**: 8–12.

---

## Phase 2 — TikTok Shop API client

**Goal**: A reusable, typed, signed Faraday client for the TikTok Shop Partner API with automatic retries, rate limit awareness, and test coverage.

### 2.1 Credentials scaffolding
Store in encrypted credentials:
```yaml
tiktok:
  app_key: ""
  app_secret: ""
  api_base_url: "https://open-api.tiktokglobalshop.com"
  auth_base_url: "https://auth.tiktok-shops.com"
  region: "US"
```

### 2.2 Faraday client class
```ruby
# app/services/tiktok/client.rb
class Tiktok::Client
  def initialize(token:, app_key: Rails.application.credentials.dig(:tiktok, :app_key), ...)
  def get(path, params = {})
  def post(path, body = {})
  private
    def connection
      Faraday.new(url: base_url) do |f|
        f.request :json
        f.request :retry, max: 3, interval: 0.5, backoff_factor: 2,
                  exceptions: [Faraday::TimeoutError, Faraday::ConnectionFailed],
                  retry_statuses: [429, 502, 503, 504]
        f.use Tiktok::Middleware::RequestSigner, app_secret:
        f.use Tiktok::Middleware::ErrorHandler
        f.response :json
        f.adapter Faraday.default_adapter
      end
    end
end
```

### 2.3 Request signing middleware
TikTok Shop uses HMAC-SHA256 signing with a specific canonical string format:
1. Sort all query params alphabetically (excluding `sign` and `access_token`)
2. Concatenate key+value pairs
3. Wrap with app_secret
4. Append request body (if not multipart)
5. Wrap again with app_secret
6. HMAC-SHA256 with app_secret, hex digest → `sign` query param

```ruby
# app/services/tiktok/middleware/request_signer.rb
class Tiktok::Middleware::RequestSigner < Faraday::Middleware
  def on_request(env)
    # compute and append `sign` to env.url
    # append `timestamp` if not present
    # append `app_key`
  end
end
```

Reference: TikTok Shop Partner Center → API Docs → Authentication → Signature Algorithm.

### 2.4 Error middleware with typed exceptions
```ruby
# app/services/tiktok/errors.rb
module Tiktok
  class Error < StandardError
    attr_reader :code, :request_id
  end
  class AuthError < Error; end           # 401, code 36004004 etc.
  class RateLimitError < Error; end      # 429 or code 35xxxxxx
  class NotFoundError < Error; end
  class ValidationError < Error; end
  class ServerError < Error; end
end
```

Middleware maps TikTok response `{code, message, request_id}` → typed exception.

### 2.5 Endpoint modules
One module per resource area, each thin wrappers returning `Data` objects (Ruby 3.2+ `Data.define`):
- `Tiktok::Resources::Authorization` — OAuth token exchange, refresh
- `Tiktok::Resources::Shop` — shop info, shop cipher
- `Tiktok::Resources::Product` — product list, product detail
- `Tiktok::Resources::AffiliateCreator` — creator search, creator detail
- `Tiktok::Resources::AffiliateCollaboration` — targeted collab create, open collab
- `Tiktok::Resources::AffiliateSample` — sample request create, status, shipping

### 2.6 Response value objects
```ruby
Tiktok::Types::Creator = Data.define(
  :external_id, :handle, :display_name, :avatar_url,
  :follower_count, :avg_views, :engagement_rate,
  :gmv_cents, :gmv_tier, :country, :categories, :raw
) do
  def self.from_api(hash)
    new(...)
  end
end
```

### 2.7 Rate limit tracking
- Inspect response headers (`X-RateLimit-Remaining`, `X-RateLimit-Reset`)
- Store per-shop rate limit state in Solid Cache
- `Tiktok::RateLimiter` helper for jobs to check before calling

### 2.8 Test harness with VCR + Webmock
- `Gemfile` (test): `vcr`, `webmock`
- Sanitized cassettes (no real tokens in fixtures)
- Unit tests per resource module
- Signing algorithm has its own tests with known-input-known-output

### 2.9 Rails runner harness for live smoke testing
`bin/rails tiktok:ping` rake task that calls a known endpoint and prints result. Used after OAuth to verify the whole stack.

**Deliverables**
- `Tiktok::Client` callable from any service or job
- All known affiliate endpoints wrapped as Ruby methods
- Test suite covers signing, errors, retries, rate limits
- No real API calls in tests; live smoke test via rake task

**Dependencies**: none (can be built in parallel with Phase 1).
**Estimated commits**: 10–15.
**Blocker**: TikTok Shop Partner Center API docs access — should be public at `partner.tiktokshop.com/docv2`.

---

## Phase 3 — OAuth (per-shop connection)

**Goal**: A shop admin clicks "Connect TikTok Shop", authorizes on TikTok, returns to our app with a working encrypted token pair that auto-refreshes.

### 3.1 OAuth URL builder
```
GET https://auth.tiktok-shops.com/oauth/authorize
  ?app_key=...
  &state=<signed shop_id + nonce>
  &redirect_uri=https://slop.bionox.info/tiktok/callback
```

### 3.2 State param
- Signed JWT or `MessageVerifier` token containing `shop_id`, `user_id`, `issued_at`, `nonce`
- Verified on callback to prevent CSRF and correctly route the returned code to the right shop

### 3.3 `Tiktok::OauthController#callback`
1. Verify `state`, extract `shop_id` and `user_id`
2. Call `Tiktok::Resources::Authorization.get_access_token(code:)`
3. Decrypt response, create or update `TiktokToken` for that shop
4. Also fetch and store `shop_cipher` (required for subsequent API calls)
5. Redirect to shop dashboard with success flash

### 3.4 Token refresh job
```ruby
# app/jobs/tiktok/refresh_token_job.rb
class Tiktok::RefreshTokenJob < ApplicationJob
  queue_as :tiktok
  def perform(tiktok_token_id)
    token = TiktokToken.unscoped.find(tiktok_token_id)
    return if !token.access_expired?(buffer: 30.minutes)
    new_tokens = Tiktok::Resources::Authorization.refresh(refresh_token: token.refresh_token)
    token.update!(
      access_token: new_tokens.access_token,
      refresh_token: new_tokens.refresh_token,
      access_expires_at: new_tokens.access_expires_at,
      refresh_expires_at: new_tokens.refresh_expires_at
    )
  end
end
```

### 3.5 Recurring schedule
`config/recurring.yml` (Solid Queue):
```yaml
tiktok_refresh_tokens:
  class: Tiktok::RefreshAllTokensJob
  schedule: every 30 minutes
```

`RefreshAllTokensJob` enqueues a `RefreshTokenJob` per token nearing expiry.

### 3.6 Connection UI
- `Shop::TiktokConnectionsController#show` — shows connected state, shop name, expiry, scopes
- Connect button → redirects to TikTok authorize URL
- Disconnect button → deletes `TiktokToken` (with confirmation)
- Connection status widget on dashboard

### 3.7 Disconnection handling
- `TiktokToken#destroy` should not cascade delete campaigns/invites (those are historical data)
- Reconnecting should reuse existing shop, just update token

**Deliverables**
- End-to-end OAuth: click → authorize → return → token stored → can call API
- Automated token refresh
- Connection status visible in UI

**Dependencies**: Phase 1 (auth), Phase 2 (client).
**Blocker**: TikTok Partner Center app credentials (app_key, app_secret).
**Estimated commits**: 6–8.

---

## Phase 4 — Creator discovery

**Goal**: A logged-in shop member can search TikTok creators with filters (GMV range, category, follower range, country), see results in a fast filterable table, bulk-select, and optionally save for later.

### 4.1 CreatorSearch service
```ruby
class Tiktok::CreatorSearch
  def initialize(shop:, filters:)
  def call
    api_response = Tiktok::Resources::AffiliateCreator.search(token:, filters:)
    api_response.creators.each { |c| upsert_creator(c) }
    cached_results_for(filters)
  end
  private
    def upsert_creator(data)
      Creator.upsert(data.to_h, unique_by: :external_id)
    end
end
```

### 4.2 Filter form
- Min/max GMV (dollars, converted to cents for query)
- GMV tier dropdown (`under_10k`, `10k_100k`, `100k_500k`, `500k_plus`)
- Category multi-select (populated from TikTok's category tree, cached)
- Follower range
- Country
- Keyword search (handle or display name)
- Sort by: GMV desc (default), followers desc, engagement rate desc

### 4.3 Results table (Hotwire)
- Turbo Frame wrapping the results
- Filter form submits via Turbo (no page reload)
- Pagination via Turbo (next/prev)
- Each row: avatar, handle, display name, follower count, GMV tier, engagement rate, invited? badge
- Bulk-select checkboxes with Stimulus controller
- Header "Select all on page" / "Clear selection"
- Selected count sticky at bottom

### 4.4 Bulk actions bar
Appears when any creator is selected:
- "Invite to campaign..." → modal picks campaign, queues bulk invite
- "Export CSV"
- "Clear selection"

### 4.5 Creator detail page
- `Shop::CreatorsController#show` — shows cached TikTok data + history of invites from this shop to this creator + any samples sent
- "Invite to campaign" button

### 4.6 Category sync job
`Tiktok::SyncCategoriesJob` — fetches TikTok's category tree, caches it in Solid Cache for 24h. Used to populate the filter.

### 4.7 Caching strategy
- Creator records act as a write-through cache
- Search results (by query hash) cached for 15 min to avoid repeat API calls
- Cache invalidated when shop performs a fresh search with same params

**Deliverables**
- Working search + filter UI
- Bulk selection state survives pagination
- Cached creators browsable even without TikTok API call
- CSV export

**Dependencies**: Phases 1, 2, 3.
**Estimated commits**: 8–12.

---

## Phase 4.5 — Message moderation pipeline

**Goal**: Stop messages from getting silently dropped by TikTok's unwritten content rules. Every outbound message — template *and* personalized variant — passes through a moderation gate that combines a fast curated keyword scanner with an AI semantic check. When TikTok rejects a message anyway, capture their error and run an AI post-mortem so the user knows *why*.

> **Why this matters**: Reacher and similar tools bulk-send messages and silently fail when TikTok's content moderation kicks in. The user (the seller) sees "0 responses" and assumes creators are ignoring them, when actually 60% of their messages were never delivered. We will not let that happen.

### 4.5.1 Curated banned-keyword list
Static, hand-maintained YAML at `config/tiktok_banned_keywords.yml`. Categories with notes:

- **Income/financial claims** — guaranteed earnings, "make money", percentages, dollar signs
- **Health/medical claims** — "FDA approved", "cure", "miracle", weight loss
- **External platform redirection** — WhatsApp, Telegram, Discord, Signal, "DM me", URLs
- **Contact info exchange** — phone numbers, emails, "call me", "reach me at"
- **Spam markers** — ALL CAPS clauses, excessive emojis (≥4 in a row), "act now", "limited time"
- **Trademarks/competitors** — Amazon, Shopify, Walmart (configurable per-shop)
- **Politics/religion** — divisive topics
- **Adult/dating/drugs/weapons** — broadly disallowed

The list will start small (~50 phrases) and grow as we observe real failures. Per-shop overrides allowed (e.g., a beauty brand may legitimately use "skincare results").

### 4.5.2 `Moderation::KeywordScanner`
Pure-function service. Takes a message string and a shop (for per-shop overrides), returns flagged phrases with category + confidence. Sub-millisecond, no API calls. Used as the first line of defense.

### 4.5.3 `Moderation::AiScanner` (Claude API)
Calls the Claude API with a focused system prompt: "You are a content moderation assistant for TikTok Shop affiliate outreach messages. Identify any phrases or claims that TikTok is likely to flag, even if they're not in a banned word list. Return JSON: {risk: 'low'|'medium'|'high', issues: [{phrase, reason, severity}], suggested_rewrite: optional}".

- Model: `claude-haiku-4-5` for speed/cost (~$0.001 per message, sub-second)
- Caching: hash the message text → cache result for 24h (Solid Cache) so re-scanning the same template is free
- Per-shop rate limiting via `Tiktok::RateLimiter` pattern (new bucket: `:moderation_ai`)

### 4.5.4 `Moderation::Result` value object
```ruby
Moderation::Result = Data.define(
  :risk,           # :low | :medium | :high | :blocked
  :issues,         # array of { phrase, category, reason, severity, source: :keyword|:ai }
  :suggested_rewrite,  # string or nil
  :scanned_at,
  :scanner_versions    # so old results can be invalidated when we update rules
)
```

### 4.5.5 `Moderation::Scanner` orchestrator
Runs `KeywordScanner` first (cheap). If it returns `:high` or `:blocked`, return immediately without calling AI. Otherwise, layer the AI scanner on top and merge results. Total worst-case latency: 1–2 seconds.

### 4.5.6 Persistence: ModerationCheck records
```
moderation_checks
  shop:references
  checkable:references {polymorphic}  # Campaign template OR Invite final message
  checked_text:text
  risk:string                          # low/medium/high/blocked
  issues:jsonb                         # full array
  suggested_rewrite:text
  scanner_versions:jsonb
  created_at
```
Indexed by `(checkable_type, checkable_id)` for fast lookup of "latest check".

### 4.5.7 Pre-send hook in BulkInviteJob (Phase 6 dependency)
The send pipeline calls `Moderation::Scanner.scan(message, shop:)` immediately before hitting TikTok. If risk is `:blocked`, the invite is marked `failed` with `error_message: "Blocked by Tikedon moderation: <reason>"` and **no API call is made**. Saves an API call and avoids account warnings.

### 4.5.8 Pre-send UI in campaign editor (Phase 5 dependency)
- Live moderation as the user types (debounced 500ms, keyword scanner only — instant)
- "Run AI check" button for the deeper scan
- Inline highlights on flagged phrases with explanation tooltip
- "Apply suggested rewrite" button if AI provided one
- Saving a template with `:high` risk requires explicit confirm

### 4.5.9 Post-failure analyzer
When `BulkInviteJob` catches a `Tiktok::ValidationError` from a send:
1. Capture TikTok's `code`, `message`, `request_id` on the Invite
2. Enqueue `Moderation::AnalyzeFailureJob`
3. The job sends the original message + TikTok's error to Claude for explanation: "Why did TikTok reject this message? What specifically should the user change?"
4. Result stored on the Invite as `failure_analysis` (jsonb)
5. Surfaced in the invite detail page with a "Rewrite and retry" button

### 4.5.10 Tests
- `KeywordScanner`: known-bad and known-good fixtures, per-shop override behavior
- `AiScanner`: stubbed Claude responses (no real API calls in tests)
- `Scanner`: short-circuit when keyword scanner returns blocked
- Persistence: ModerationCheck creation, polymorphic association, latest-check lookup

**Deliverables**
- Every message that reaches TikTok has been scanned
- Hard-blocked messages never reach the API
- Failed sends include an AI-generated explanation
- User can iterate on templates with confidence

**Dependencies**: Phase 1 (auth/shops), Phase 2 (rate limiter pattern), Claude API key.
**Estimated commits**: 8–12.

---

## Phase 5 — Campaign management

**Goal**: A shop admin creates an affiliate campaign tied to a product, with commission rate, sample offer, and message template. This is the container for invites.

### 5.1 Campaign CRUD
- `Shop::CampaignsController` full CRUD
- Index: list all campaigns with counts (invites sent, accepted, samples shipped)
- New/Edit form: name, product SKU selector, commission rate, sample offer toggle, message template, status
- Show: dashboard for this campaign (stats + list of invites)

### 5.2 Product picker
- TikTok product list comes from `Tiktok::Resources::Product.list`
- Synced periodically via `Tiktok::SyncProductsJob`
- Cached in a `Product` model (not in current schema — add in this phase)
- Form uses a combobox (Stimulus autocomplete) for searching products

### 5.3 Message template with variable substitution
Allowed variables:
- `{{creator.handle}}`
- `{{creator.display_name}}`
- `{{shop.name}}`
- `{{campaign.name}}`
- `{{campaign.commission_rate}}`
- `{{product.name}}`

Template preview renders with example creator data.

### 5.4 Campaign status machine
Status transitions: `draft` → `active` → `paused` / `ended`.
- Draft: can edit anything, no invites allowed
- Active: can send invites, can edit only message template
- Paused: no new invites, existing ones continue
- Ended: read-only

### 5.5 New model: Product
```
products
  shop:references
  external_id (TikTok product SKU)
  name
  image_url
  price_cents
  status
  raw (jsonb)
  synced_at
```

**Deliverables**
- Campaign CRUD with product picker
- Message template with preview
- Status machine enforced
- `Product` model + sync job

**Dependencies**: Phase 1, Phase 2.
**Estimated commits**: 6–10.

---

## Phase 5.5 — Product knowledge base + AI message crafter

**Goal**: Stop sending generic "love your content!" messages. For each TikTok Shop product, store rich structured info (ingredients, claims, target audience, USPs) and use it to generate genuinely product-specific outreach that references what the creator could *actually say* about the product on camera.

> **Why this matters**: Bulk outreach with generic templates gets ignored. Outreach that references the *specific* product the creator would receive — its unique angle, who it's for, what makes it different — gets responses. Sellers know their products; the system needs to know them too.

### 5.5.1 ProductKnowledge schema
Extends the `Product` model added in Phase 5 with a one-to-one ProductKnowledge:

```
product_knowledges
  product:references {unique}
  short_description:text         # one-sentence product summary
  long_description:text          # paragraph, used as primary AI input
  ingredients:text               # raw text — supplements/cosmetics use case
  benefits:text                  # bullet-form claims
  target_audience:text           # who it's for
  use_cases:text                 # how/when it's used
  usp:text                       # unique selling proposition
  certifications:string[]        # FDA, USDA Organic, vegan, gluten-free, etc.
  brand_name:string
  brand_voice:text               # tone guidelines (e.g. "friendly, scientific, never hyped")
  retail_price_cents:bigint
  size_or_serving:string         # "60 capsules", "200ml", etc.
  warnings:text                  # allergens, contraindications
  source_urls:string[]           # where info was imported from (label PDF, brand page)
  imported_at:datetime
  imported_by:references {user}
  raw_imports:jsonb              # original source data for re-extraction
```

### 5.5.2 Import mechanisms
Multiple ways to populate ProductKnowledge:

1. **Manual form** — sectioned editor in `/shop/products/:id/knowledge`
2. **CSV bulk import** — for sellers with 50+ SKUs
3. **URL fetch + AI extraction** — paste a Shopify product URL, an Amazon listing URL, or a brand page URL → background job fetches the page, sends to Claude with prompt "Extract product info into this JSON schema", saves result as draft for review
4. **Image OCR** (later) — paste a product label photo → vision model extracts ingredients
5. **TikTok product page sync** — Phase 5's `Tiktok::SyncProductsJob` already fetches basic product data from TikTok; this layer enriches it

Imports always go through review before becoming canonical — never blindly accept AI-extracted data.

### 5.5.3 `Ai::Client` (new shared service)
Thin wrapper around the Anthropic Ruby SDK. Single entry point for all AI calls in the app (moderation, message crafting, post-failure analysis, future features).
- API key in Rails credentials (`anthropic.api_key`)
- Configurable model per call site (default `claude-haiku-4-5` for cheap/fast, `claude-sonnet-4-6` for nuanced work)
- Built-in retry/timeout
- Logs token usage per call for cost tracking
- Per-shop rate limit bucket (`:ai_calls`) to prevent runaway

### 5.5.4 `Messaging::Crafter` service
Generates outreach messages from a structured prompt:

```ruby
Messaging::Crafter.call(
  campaign:          campaign,    # contains product, commission_rate, sample_offer, etc.
  creator:           creator,     # TikTok handle, follower_count, niche if known
  product_knowledge: pk,          # the rich structured data
  variant:           :template,   # :template (one-to-many) | :personalized (per-creator)
  tone:              "friendly",  # or pulls from product.brand_voice
  max_length:        500
)
# returns Messaging::Result.new(text:, moderation_result:, ai_metadata:)
```

The crafter:
1. Builds a structured prompt with product info, creator context, campaign goals
2. Calls Claude
3. **Pipes the output through `Moderation::Scanner` automatically** before returning
4. If moderation flags it, retries up to 2x with "rewrite to avoid these phrases: [...]" instructions
5. Returns the final message + moderation result

### 5.5.5 Two crafting modes
**Template mode** (cheap, called once per campaign):
- Generates a base template with `{{creator.handle}}` and `{{creator.display_name}}` variables
- One Claude call per campaign
- Stored on `Campaign.message_template`
- Variables substituted at send time without further AI calls

**Personalized mode** (expensive, called per creator at send time):
- Per-invite call to Claude with the *specific* creator's data
- Adds 1-3 sentences referencing their niche, follower size, content style
- Costs ~$0.005-0.01 per invite vs ~$0.0001 for template mode
- Optional toggle on Campaign: `personalize_per_creator: boolean`
- Uses `Tiktok::RateLimiter` bucket `:ai_personalize` to cap spend (default: 200/day per shop)

### 5.5.6 Caching
- Template mode: cache result keyed by `(product_id, campaign_settings_hash, brand_voice_hash)` → never re-generate the same template
- Personalized mode: cache by `(template_hash, creator_id)` → if you re-run a campaign for the same creators, no re-spend

### 5.5.7 Campaign editor integration (Phase 5 update)
- "Generate from product" button next to message template field
- Modal: select tone, length, optional special instructions ("emphasize the vegan certification", "mention the 30-day money-back guarantee")
- Click → spinner → result populates the editor → user can edit
- "Run AI check" calls `Moderation::Scanner` independently

### 5.5.8 Bulk invite integration (Phase 6 update)
- BulkInviteJob respects `campaign.personalize_per_creator`
- If true: each `SendInviteJob` calls `Messaging::Crafter` for that specific creator
- If false: uses the saved template with variable substitution
- Either way, the final message is moderation-scanned before sending (Phase 4.5 hook)

### 5.5.9 Cost tracking
Add `ai_usage_logs` table:
```
ai_usage_logs
  shop:references
  feature:string                 # "moderation" | "crafter_template" | "crafter_personalized" | "failure_analysis"
  model:string
  input_tokens:integer
  output_tokens:integer
  cost_cents:integer
  request_id:string
  created_at
```
Aggregate daily for the admin dashboard. Per-shop monthly cap configurable.

### 5.5.10 Tests
- `Ai::Client` with stubbed Anthropic responses
- `Messaging::Crafter` template mode and personalized mode with stubbed AI
- Crafter retries when moderation blocks the AI's output
- ProductKnowledge import (URL → extracted JSON) with stubbed Claude
- Cost log creation per call

**Deliverables**
- Per-product knowledge base with multiple import mechanisms
- AI-crafted message templates that reference specific product attributes
- Optional per-creator personalization at send time
- Every crafted message moderation-scanned before sending
- Per-shop AI cost tracking

**Dependencies**: Phase 4.5 (moderation), Phase 5 (Campaign + Product), Anthropic API key.
**Estimated commits**: 12–18.

---

## Phase 6 — Bulk invite engine

**Goal**: From the creator search or a saved list, bulk-invite to a campaign. Rate-limited. Per-invite status visible in real time via Turbo Streams.

### 6.1 Invite creation flow
- User selects creators → clicks "Invite to campaign"
- Modal: pick active campaign, preview message template with first creator's data
- Submit → creates `Invite` records (status `pending`) in one transaction → enqueues `BulkInviteJob`

### 6.2 BulkInviteJob
```ruby
class Tiktok::BulkInviteJob < ApplicationJob
  def perform(shop_id, campaign_id, creator_ids)
    Current.shop = Shop.find(shop_id)
    creator_ids.each_with_index do |cid, i|
      Tiktok::SendInviteJob
        .set(wait: (i * rate_limit_delay).seconds)
        .perform_later(invite_id_for(cid, campaign_id))
    end
  end
end
```

### 6.3 SendInviteJob
- Loads invite with `unscoped` (background jobs don't have a request context — set `Current.shop` explicitly)
- Updates status to `sending`
- Calls `Tiktok::Resources::AffiliateCollaboration.create_targeted`
- On success: status `sent`, stores `external_id`, `sent_at`
- On rate limit: reschedule with exponential backoff, increment `retry_count`
- On auth error: mark invite `failed`, enqueue `RefreshTokenJob`, retry
- On validation error: mark invite `failed` with error_message
- Broadcasts Turbo Stream update to the campaign show page

### 6.4 Per-shop rate limiter
- Solid Cache stores `tiktok:ratelimit:shop_#{shop_id}:invites_sent_#{window}`
- Configurable per-shop limit (default: conservative — 1 invite / 2 seconds, 60 / minute)
- `BulkInviteJob` spreads jobs over time to respect the limit

### 6.5 Invite status page
- `Shop::InvitesController#index` — filterable list (by campaign, status, date)
- Turbo Stream updates when jobs complete
- Retry failed invites button
- Cancel pending invites button

### 6.6 Status sync job
`Tiktok::SyncInviteStatusJob` — periodically polls TikTok for updates on `sent` invites to detect `accepted` / `declined` transitions. Runs every 15 min per shop.

### 6.7 Failure handling
- `retry_count` caps at 3
- After cap, invite marked `failed` with reason stored
- Admin UI to bulk-retry all failed invites for a campaign

**Deliverables**
- Bulk invite a hundred creators without crashing or spamming
- Real-time status updates in the UI
- Rate-limit compliant
- Retry flow for failures

**Dependencies**: Phases 2, 3, 4, 5.
**Estimated commits**: 10–14.

---

## Phase 7 — Sample fulfillment

**Goal**: Track which creators got samples, what status they're in, shipping info, and delivery confirmation. Optionally trigger sample creation from an invite.

### 7.1 Sample creation
- Manual: on any `accepted` invite, button "Send sample" → creates `Sample` → calls `Tiktok::Resources::AffiliateSample.create`
- Automatic: campaigns with `sample_offer: true` auto-create sample when invite is accepted

### 7.2 Sample status machine
`requested` → `approved` → `shipped` → `delivered` (terminal)
Or: `rejected` / `returned` (terminal negative)

### 7.3 Sync job
`Tiktok::SyncSampleStatusJob` — polls per shop every 30 min for status updates, shipping info, tracking numbers.

### 7.4 Sample UI
- `Shop::SamplesController#index` — list with status filter, search by creator handle
- Columns: creator, campaign, status, tracking number, carrier, shipped_at, delivered_at
- Show page: full shipping detail, link to invite, link to creator

### 7.5 Sample cost tracking (optional for v1)
- Add `cost_cents` to samples (manual entry, for ROI math later)
- Aggregate view: "$X spent on samples for campaign Y"

**Deliverables**
- Samples are created, tracked, status synced
- Shipping info visible to shop admins

**Dependencies**: Phases 2, 3, 6.
**Estimated commits**: 5–8.

---

## Phase 8 — Performance & analytics

**Goal**: Shop-level dashboard showing what's working and what's not. Nothing fancy — just the numbers that let you make decisions.

### 8.1 Shop dashboard widgets
- Total invites sent (all time / last 30 days)
- Acceptance rate
- Samples shipped vs delivered
- Top performing creators (by acceptance + sample delivery)
- Recent activity feed

### 8.2 Per-campaign analytics
- Invite funnel: sent → accepted → sample shipped → delivered
- Time-to-acceptance histogram
- Creator tier breakdown

### 8.3 Per-creator analytics
- History of invites across all campaigns (for this shop)
- Acceptance rate of this creator in our shop

### 8.4 Metrics tables
Pre-computed aggregations stored in a `metrics_daily` table, updated by `Metrics::RecomputeJob` nightly. Avoids expensive live queries.

**Deliverables**
- Dashboard shows meaningful numbers
- Per-campaign drill-down page

**Dependencies**: Phases 6, 7.
**Estimated commits**: 5–8.

---

## Phase 9 — Shop-level user management UI

**Goal**: Shop admins can invite, remove, and re-role teammates. Signup flow via email invite link.

### 9.1 Invite users
- `Shop::MembersController#new/create` — enter email + role
- Creates a pending `Membership` with `invited_at`
- Emails an invite link with signed token (`MessageVerifier`)
- Recipient clicks link → if no account, sees signup form; if account exists, accept prompt

### 9.2 Member list + management
- Show all memberships for current shop
- Change role (admin/member, only if current user is owner/admin)
- Remove member (with confirmation)
- Resend invite

### 9.3 Transfer ownership
Only owner can transfer to another admin. Two-step confirmation.

### 9.4 Leave shop
Non-owners can leave. Owner must transfer or delete shop first.

### 9.5 Email delivery
- Configure SMTP via Rails credentials (likely Postmark, Resend, or Amazon SES)
- `InvitationMailer` with HTML + text template

**Deliverables**
- Shop admins can build a team without touching the Rails console
- Invite emails actually arrive

**Dependencies**: Phase 1.
**Estimated commits**: 6–10.

---

## Phase 10 — Platform admin console

**Goal**: You (platform admin) have a separate console to see all shops, all users, system health, and intervene when needed.

### 10.1 Admin dashboard
- Total shops, users, invites sent, samples shipped
- Recent signups
- System health (queue depth, failing jobs, error rate)

### 10.2 Shop management
- List all shops with filter (status, plan, created_at)
- Detail page: members, connection status, usage stats
- Disable / re-enable a shop

### 10.3 User management
- List all users (across shops)
- Reset password
- Disable account
- View which shops a user belongs to

### 10.4 Impersonation (optional)
- "View as this user" — sets `Current.user`, marks session with `impersonating_user_id`
- All actions logged to audit table
- Highly visible banner during impersonation
- One-click exit

### 10.5 Audit log (optional but recommended)
- `AuditEvent` model records: user, shop, action, target, metadata
- Logged for sensitive actions: login, role change, TikTok connect/disconnect, bulk invite, shop settings change
- Admin-only view

### 10.6 Background job console
- Solid Queue has `solid_queue-dashboard` gem or we can use `mission_control-jobs`
- Mount at `/admin/jobs`, locked to platform admin

**Deliverables**
- You can manage the platform without touching the Rails console

**Dependencies**: All previous phases.
**Estimated commits**: 8–12.

---

## Phase 11 — Production hardening

**Goal**: Nothing goes to `slop.bionox.info` until this phase is green.

### 11.1 Error tracking
- Sentry or Honeybadger (free tier)
- Per-environment DSN in credentials
- Exclude noisy errors (e.g. invalid CSRF from abandoned sessions)

### 11.2 Structured logging
- `rails_semantic_logger` gem — JSON logs
- Include `shop_id`, `user_id`, `request_id` in every log line
- Log TikTok API calls with response time and rate limit headers

### 11.3 Health check endpoint
- `/up` (already exists in Rails 8)
- `/health` — also checks DB, Solid Queue, TikTok API reachability

### 11.4 Brakeman + bundler-audit in CI
- Both already in Gemfile
- Run on every commit (GitHub Actions or local pre-push hook)

### 11.5 Database backups
- Nightly `pg_dump` to off-machine storage
- Weekly restore test on staging

### 11.6 Rate limit safeguards
- Hard cap on bulk invite size (configurable per shop, default 500/day)
- UI warning when approaching TikTok per-shop daily limits

### 11.7 ToS compliance audit
- Review TikTok Shop Partner API terms for anything we're accidentally violating
- Ensure we're not scraping, only using documented endpoints
- Add ToS page + privacy policy

### 11.8 Load test basics
- Simulate 100 creators bulk invite on staging
- Verify Solid Queue handles it
- Profile slow queries with `bullet` gem

**Deliverables**
- Green health check
- Error tracking wired up
- Security scan clean
- Backup strategy documented and tested

**Dependencies**: Phases 1–10.
**Estimated commits**: 6–10.

---

## Phase 12 — Deploy to repify server as tikedon.com

**Goal**: `https://tikedon.com` is live, SSL-secured via Cloudflare + Let's Encrypt, running under Apache + Passenger, co-tenanted with Repify.me and bionox.info without disturbing either.

> **Read [Server co-tenancy](#server-co-tenancy--do-not-break) before starting this phase.** Every command in this phase touches a server with two other live apps. The Repify.me Passenger vhost is the reference pattern — we match it, not replace it.

### 12.1 Pre-flight checks (read-only)
Run before touching anything:
- [ ] Confirm Ruby 3.3.6 still available at `/usr/local/rvm/gems/ruby-3.3.6/wrappers/ruby`
- [ ] Confirm Repify.me and bionox.info are both serving (`curl -I https://repify.me`, `curl -I https://bionox.info`)
- [ ] Confirm Postgres 16 running, `prod_user_9988` role exists
- [ ] Confirm `/var/www/tikedon.com` does NOT already exist
- [ ] Confirm no Apache vhost named `tikedon.com*` exists in `sites-available` or `sites-enabled`

### 12.2 Create deploy user context and directories
As root:
```bash
sudo -u prod_user_9988 bash -lc "mkdir -p /var/www/tikedon.com"
chgrp www-data /var/www/tikedon.com
chmod 2755 /var/www/tikedon.com
```

### 12.3 Production database
As `postgres` superuser:
```sql
CREATE DATABASE tikedon_production OWNER prod_user_9988 ENCODING 'UTF8' LC_COLLATE 'C.UTF-8' LC_CTYPE 'C.UTF-8' TEMPLATE template0;
```
(Using `prod_user_9988` as owner for consistency with the other two DBs on the host. If we later want least-privilege, we can reassign — but this is the path of least co-tenant risk.)

Rails will also create Solid Queue / Cache / Cable tables in the same database via separate migration paths (Rails 8 default).

### 12.4 First deploy — clone and build
As `prod_user_9988`:
```bash
cd /var/www/tikedon.com
git clone git@github.com:Fladdermuz/TikTokSlop.git .
echo "3.3.6" > .ruby-version  # already committed from dev, just confirm
source /usr/local/rvm/scripts/rvm
rvm use 3.3.6
gem install bundler
bundle config set --local deployment 'true'
bundle config set --local without 'development test'
bundle install
```

### 12.5 Master key and credentials
`RAILS_MASTER_KEY` must be on the server but never committed. Options (pick one at deploy time):
- **Option A**: scp `config/master.key` once from dev to `/var/www/tikedon.com/config/master.key`, chmod 600, chown prod_user_9988
- **Option B**: store in `/var/www/tikedon.com/.env.production` and source via Passenger env vars
- **Option C**: use Rails 8 `config/credentials/production.key` with a separate production credentials file (preferred for clean prod/dev split)

Recommend **Option C**: `bin/rails credentials:edit --environment production` locally, commit the `.enc` file, scp only the `.key`.

### 12.6 Environment variables Passenger needs
In the Apache vhost (see 12.8), set:
```
SetEnv RAILS_ENV production
SetEnv RAILS_MASTER_KEY <from file or kept out of apache config via PassengerEnvVarsFromConfig>
SetEnv RAILS_LOG_TO_STDOUT 1
SetEnv RAILS_SERVE_STATIC_FILES 1
```

Preferred: put secrets in a file `/var/www/tikedon.com/.env.production` readable only by `prod_user_9988`, and use a small wrapper that sources it before Passenger boots. Or use `PassengerAppEnv production` and rely on Rails credentials.

### 12.7 Database setup and asset precompile
```bash
cd /var/www/tikedon.com
RAILS_ENV=production bin/rails db:prepare   # creates if missing, migrates
RAILS_ENV=production bin/rails db:seed      # creates first platform admin
RAILS_ENV=production bin/rails assets:precompile
RAILS_ENV=production bin/rails tailwindcss:build
```

### 12.8 Apache vhost — HTTP (pre-SSL)
`/etc/apache2/sites-available/tikedon.com.conf`:
```apache
<VirtualHost *:80>
    ServerName tikedon.com
    ServerAlias www.tikedon.com
    DocumentRoot /var/www/tikedon.com/public

    PassengerRuby /usr/local/rvm/gems/ruby-3.3.6/wrappers/ruby
    PassengerAppRoot /var/www/tikedon.com
    PassengerAppEnv production
    PassengerFriendlyErrorPages off

    <Directory /var/www/tikedon.com/public>
        Options -MultiViews
        Require all granted
        AllowOverride None
    </Directory>

    ErrorLog  ${APACHE_LOG_DIR}/tikedon.com-error.log
    CustomLog ${APACHE_LOG_DIR}/tikedon.com-access.log combined
</VirtualHost>
```

Enable:
```bash
a2ensite tikedon.com.conf
apache2ctl configtest   # MUST pass before reload
systemctl reload apache2
```

### 12.9 SSL via Let's Encrypt
Cloudflare must be **DNS-only** (grey cloud) during issuance, OR use DNS-01 challenge. Prefer DNS-only for simplicity:
```bash
certbot --apache -d tikedon.com -d www.tikedon.com --non-interactive --agree-tos -m <email>
```
This auto-generates `tikedon.com-le-ssl.conf` in `sites-available` and enables it.

After cert issuance, re-enable Cloudflare proxy (orange cloud) with SSL mode **Full (strict)**.

### 12.10 Solid Queue worker as systemd service
`/etc/systemd/system/tikedon-jobs.service`:
```ini
[Unit]
Description=TikTokSlop Solid Queue worker
After=network.target postgresql.service

[Service]
Type=simple
User=prod_user_9988
Group=www-data
WorkingDirectory=/var/www/tikedon.com
Environment=RAILS_ENV=production
ExecStart=/usr/local/rvm/gems/ruby-3.3.6/wrappers/bundle exec rails solid_queue:start
Restart=on-failure
RestartSec=5
StandardOutput=append:/var/log/tikedon/jobs.log
StandardError=append:/var/log/tikedon/jobs.err.log

[Install]
WantedBy=multi-user.target
```
Then:
```bash
mkdir -p /var/log/tikedon
chown prod_user_9988:prod_user_9988 /var/log/tikedon
systemctl daemon-reload
systemctl enable --now tikedon-jobs
systemctl status tikedon-jobs
```

### 12.11 Deploy script
`/var/www/tikedon.com/bin/deploy`:
```bash
#!/usr/bin/env bash
set -euo pipefail
cd /var/www/tikedon.com
source /usr/local/rvm/scripts/rvm
rvm use 3.3.6
git fetch --all
git reset --hard origin/main
bundle install --deployment --without development test
RAILS_ENV=production bin/rails db:migrate
RAILS_ENV=production bin/rails assets:precompile
RAILS_ENV=production bin/rails tailwindcss:build
touch tmp/restart.txt                 # Passenger graceful restart
systemctl restart tikedon-jobs         # Needs sudoers rule (see 12.12)
echo "deploy complete: $(git rev-parse --short HEAD)"
```

Invoked from dev: `ssh repify "/var/www/tikedon.com/bin/deploy"`

### 12.12 Sudoers entry for restart
Allow `prod_user_9988` to restart only the tikedon-jobs service without password:
`/etc/sudoers.d/tikedon-jobs`:
```
prod_user_9988 ALL=(root) NOPASSWD: /bin/systemctl restart tikedon-jobs, /bin/systemctl status tikedon-jobs
```

### 12.13 First deploy checklist
- [ ] Pre-flight checks green (12.1)
- [ ] Repify.me still serving (`curl -I https://repify.me`)
- [ ] bionox.info still serving (`curl -I https://bionox.info`)
- [ ] `/var/www/tikedon.com` exists, owned correctly
- [ ] `tikedon_production` DB created, migrated, seeded
- [ ] `assets:precompile` clean
- [ ] Apache configtest clean
- [ ] `tikedon.com.conf` enabled (HTTP first)
- [ ] `curl -I http://tikedon.com` → 200 via Passenger
- [ ] Let's Encrypt cert issued
- [ ] `curl -I https://tikedon.com` → 200
- [ ] Can log in as platform admin
- [ ] Solid Queue systemd service active and processing jobs
- [ ] Error tracking receives test event
- [ ] Logs writing to `/var/log/tikedon/` and `${APACHE_LOG_DIR}/tikedon.com-*`
- [ ] **Repify.me and bionox.info STILL serving** (final sanity check)

### 12.14 TikTok app production approval
- Submit app for production review at `partner.tiktokshop.com`
- Provide TikTok with:
  - Production redirect URI: `https://tikedon.com/tiktok/callback`
  - Demo video of the flow
  - Privacy policy URL: `https://tikedon.com/privacy`
  - ToS URL: `https://tikedon.com/terms`
- Wait for approval

### 12.15 Rollback procedure
If a deploy breaks things:
```bash
ssh repify "cd /var/www/tikedon.com && \
  git reset --hard <previous_sha> && \
  bundle install --deployment --without development test && \
  RAILS_ENV=production bin/rails db:rollback  # only if a migration caused it
  touch tmp/restart.txt && \
  systemctl restart tikedon-jobs"
```
For hard breaks (Passenger won't start), `a2dissite tikedon.com` and reload Apache — this leaves Repify.me and bionox.info untouched.

**Deliverables**
- Live at `https://tikedon.com`
- Passenger managing web tier under `prod_user_9988`
- Solid Queue worker as a systemd service
- Repify.me and bionox.info completely undisturbed
- Reproducible deploy script

**Dependencies**: All previous phases.
**Estimated commits**: 4–6 (plus server-side config files that aren't in the repo).

---

## Phase 13 — Post-launch (optional)

Everything below is opt-in. None of it blocks launch.

- **Self-serve signup** — public signup page, create your own shop after verifying email
- **Billing** — Stripe Checkout + webhooks, plan limits enforced in policies
- **Organization layer** — group multiple shops under an Organization entity
- **Webhooks from TikTok** — real-time invite/sample status instead of polling
- **AI-assisted outreach** — template generation, response analysis
- **Multi-region** — TikTok Shop EU, SEA region support
- **Creator lists** — save groups of creators for reuse across campaigns
- **Sequences** — multi-step outreach (initial invite → follow-up if no response)
- **API for your own automation** — token-based API to integrate with Zapier / n8n
- **Mobile-responsive polish** — current plan is desktop-first admin UI
- **Dark mode**

---

## Cross-cutting concerns

### Testing strategy
- **Unit tests**: models (validations, scopes), policies, service objects, Faraday middleware
- **System tests (Capybara)**: login, create shop, connect TikTok (mocked), search creators, bulk invite
- **Tenant isolation tests**: every shop-scoped model gets a test asserting cross-tenant reads return nothing
- **VCR cassettes**: all TikTok API interactions in tests use recorded cassettes, sanitized for secrets
- **CI**: run on every push via GitHub Actions

### Git workflow
- Main branch is deployable
- One branch per phase, merged to main when green
- Small commits within a phase — each commit should compile and test-pass
- Use `Co-Authored-By: Claude` in commits per CLAUDE.md convention
- Tag releases (`v0.1.0`) at end of each major phase post-launch

### Documentation
- `docs/PLAN.md` (this file) — updated as phases complete
- `docs/ARCHITECTURE.md` — high-level diagrams, maintained
- `docs/TIKTOK_API_NOTES.md` — gotchas discovered during Phase 2
- `README.md` — setup instructions, environment variables, deploy steps
- `CLAUDE.md` — instructions for future Claude Code sessions (similar to bionox.info's)

### Secrets management
- All secrets in `Rails.application.credentials` (encrypted)
- `RAILS_MASTER_KEY` stored in `~/.rails_master_key_tiktokslop` on bionox server (not committed)
- Per-environment credentials files (`credentials/production.yml.enc`)

### Database conventions
- All `jsonb` columns default to `{}`, not null
- All foreign keys have database-level FK constraints
- All tenant-scoped tables have `shop_id` with an index
- Soft delete via `discarded_at` only if we actually need it (not in v1)

---

## Open questions

Things I'll need your answer on at the point each phase starts. None block Phase 0–2.

1. **Shop signup** — are you manually creating shops in the Rails console for v1, or do we want a minimal "create shop" form from the start?
2. **Email provider** — which SMTP (Postmark / Resend / SES / other)? Blocks Phase 9.
3. **Error tracking** — Sentry, Honeybadger, something else? Free tier fine?
4. **TikTok region(s)** — US only, or also EU / SEA? Affects API base URLs and Phase 2.
5. **Product catalog sync frequency** — daily? Hourly? On-demand? Affects Phase 5.
6. **Message template language** — plain variables (`{{creator.handle}}`), Liquid, or something richer?
7. **Per-shop rate limits** — start conservative and loosen, or get actual TikTok limit values from Partner Center first?
8. **Audit log** — in v1 or post-launch? Affects Phase 10.
9. **Impersonation** — in v1 or post-launch? Affects Phase 10.
10. **Legal** — who writes the ToS and privacy policy? Blocks Phase 12 (TikTok app production review).

---

## Blocker log

Track blockers as they appear. Update status and resolution.

| Date | Blocker | Status | Resolution |
|------|---------|--------|------------|
| 2026-04-09 | TikTok Shop Partner Center app credentials (app_key, app_secret) needed | open | Register at `partner.tiktokshop.com`, create Affiliate app, submit for sandbox approval |
| 2026-04-09 | Confirmation of active TikTok Shop seller account | open | Required before any OAuth testing |
| 2026-04-09 | Production domain confirmed as `tikedon.com` (CF → 146.190.139.89 = repify server) | resolved | Plan Phase 12 fully updated for Passenger + tikedon.com. Repify.me and bionox.info co-tenancy documented. |
| 2026-04-09 | Email provider for Phase 9 (invites, password reset) | open | Decide between Postmark, Resend, Amazon SES before Phase 9 starts |
| 2026-04-09 | Legal — ToS and privacy policy content for tikedon.com | open | Required for Phase 12 (TikTok production app review) |
| 2026-04-09 | Anthropic Claude API key for moderation + message crafting | open | Required for Phases 4.5 and 5.5. Defaulting to Claude API (Anthropic) since we're already in that ecosystem; if Matt prefers OpenAI we can swap. |
| 2026-04-09 | New requirement: pre-send moderation pipeline | resolved | Added as Phase 4.5 — keyword scanner + AI scanner + post-failure analyzer. Sits before Phase 5/6 in dependency order. |
| 2026-04-09 | New requirement: per-product knowledge base + AI message crafter | resolved | Added as Phase 5.5 — ProductKnowledge schema, multiple import paths (manual, CSV, URL+AI extraction), Messaging::Crafter with template + per-creator personalized modes, cost tracking. |

---

## Notes for future Claude sessions

- When resuming this project, start with `TaskList` to see the current task state, then read this file to understand which phase we're in.
- `Phase status` table at the top is the quick indicator.
- Always update this file at the end of a phase completion, not during.
- Never skip tenant isolation tests — they're the only tests that protect against the most expensive possible bug.
- When in doubt about a TikTok API call, check `docs/TIKTOK_API_NOTES.md` first for known gotchas.
