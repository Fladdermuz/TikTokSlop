# TikTokSlop — Master Build Plan

A multi-tenant Rails 8 application for automating TikTok Shop affiliate outreach,
creator discovery, targeted collaborations, and sample fulfillment. Built as a
proper SaaS from day one, deployable for personal use first and for external
customers later.

**Repo**: `github.com/Fladdermuz/TikTokSlop`
**Stack**: Rails 8.1 / Ruby 3.3 / Postgres 17 / Hotwire / Tailwind / Solid Queue
**Target deploy**: `slop.bionox.info` (subdomain on existing bionox server)

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
| 5 | Campaign management | ⏸ pending |
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

## Phase 12 — Deploy to bionox server

**Goal**: `slop.bionox.info` is live, SSL, running as a separate PM2 process on the existing bionox server.

### 12.1 Production database
- Create `tiktokslop_production` on bionox Postgres
- Dedicated DB user with limited permissions
- Store DATABASE_URL in Rails credentials (production env)

### 12.2 DNS + SSL
- Add A record for `slop.bionox.info` → bionox server IP
- Apache virtual host with Let's Encrypt cert via certbot
- Reverse proxy to `localhost:3002` (next port after bionox.info's 3001)

### 12.3 Rails production config
- `RAILS_ENV=production`
- Asset precompilation (Tailwind + propshaft)
- `RAILS_MASTER_KEY` securely deployed (not committed)
- Force SSL, HSTS
- Session cookie `secure: true`

### 12.4 Process manager
Two PM2 processes:
- `tiktokslop-web` — Puma on port 3002
- `tiktokslop-jobs` — `bin/jobs` (Solid Queue worker)

Both start on boot.

### 12.5 Deploy script
```bash
ssh bionox "cd /var/www/slop.bionox.info && \
  git pull origin main && \
  bundle install && \
  RAILS_ENV=production bin/rails db:migrate && \
  RAILS_ENV=production bin/rails assets:precompile && \
  pm2 restart tiktokslop-web tiktokslop-jobs"
```

Add to `CLAUDE.md` in this repo so future sessions know how to deploy.

### 12.6 First deploy checklist
- [ ] DB migrated
- [ ] Assets precompiled
- [ ] Health check returns 200
- [ ] Login works
- [ ] Can create shop, connect TikTok, send one test invite
- [ ] Solid Queue processing jobs
- [ ] Logs visible via `pm2 logs`
- [ ] Error tracking receives test event
- [ ] SSL grade A
- [ ] Backup runs

### 12.7 TikTok app production approval
- Submit app for production review (separate from sandbox)
- Provide TikTok with:
  - Production redirect URI
  - Demo video of the flow
  - Privacy policy + ToS URLs
- Wait for approval

**Deliverables**
- Live site at `slop.bionox.info`
- You can log in and use it end-to-end

**Dependencies**: All previous phases.
**Estimated commits**: 4–6.

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

---

## Notes for future Claude sessions

- When resuming this project, start with `TaskList` to see the current task state, then read this file to understand which phase we're in.
- `Phase status` table at the top is the quick indicator.
- Always update this file at the end of a phase completion, not during.
- Never skip tenant isolation tests — they're the only tests that protect against the most expensive possible bug.
- When in doubt about a TikTok API call, check `docs/TIKTOK_API_NOTES.md` first for known gotchas.
