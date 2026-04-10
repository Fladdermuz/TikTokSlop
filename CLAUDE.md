# Tikedon (TikTokSlop) — Claude Code Instructions

## What is this?

Multi-tenant Rails 8 SaaS for automating TikTok Shop affiliate outreach: creator discovery, AI-crafted messages, campaign management, bulk invites with moderation, sample fulfillment, and Spark Code collection.

## Deployment

### Production
- **Domain**: tikedon.com (Cloudflare → 146.190.139.89)
- **Server**: `ssh repify` (same box as bionox.info and Repify.me)
- **Path**: `/var/www/tikedon.com`
- **Web**: Apache + Phusion Passenger
- **Ruby**: 3.3.6 via RVM (`/usr/local/rvm/gems/ruby-3.3.6/wrappers/ruby`)
- **DB**: Postgres 16, database `tikedon_production`
- **Jobs**: Solid Queue via systemd (`tikedon-jobs.service`)
- **Deploy user**: `prod_user_9988`

### Deploy command (once set up)
```bash
ssh repify "/var/www/tikedon.com/bin/deploy"
```

### CRITICAL — Do not break co-tenants
The repify server also runs:
- **Repify.me** (Rails 7.2, Passenger, port via Passenger)
- **bionox.info** (Next.js, PM2, port 3001)

Never modify their Apache vhosts, PM2 config, databases, or Ruby installations.

## Development

```bash
cd /Users/matt/Desktop/TikTokSlop
bin/rails db:prepare
bin/rails db:seed
bin/rails db:seed:creators
bin/rails db:seed:products
bin/rails db:seed:product_knowledge
bin/dev  # or bin/rails server
```

Login: `matt@tikedon.com` / `password1234`

### Running tests
```bash
bin/rails test
```

### Key rake tasks
```bash
bin/rails tiktok:ping              # Smoke test TikTok API with saved token
bin/rails tiktok:sign_debug[path]  # Debug signing for a given path
bin/rails db:seed:creators         # 320 fake creators
bin/rails db:seed:products         # 6 dev products
bin/rails db:seed:product_knowledge # knowledge for 3 products
```

## Architecture

- **Multi-tenant**: `Current.shop` + `ShopScoped` concern on all tenant tables
- **TikTok API**: `Tiktok::Client` with HMAC-SHA256 signing middleware
- **AI**: `Ai::Client` wrapping Anthropic gem for moderation + message crafting
- **Moderation**: `Moderation::Scanner` → KeywordScanner + AiScanner (Claude Haiku)
- **Message crafting**: `Messaging::Crafter` → Claude Sonnet, template + personalized modes
- **Background jobs**: Solid Queue (`tiktok` queue) for invites, token refresh, sample sync, follow-ups
- **Recurring**: Token refresh (30 min), invite status sync (15 min), Spark Code follow-ups (2 hr)

## Credentials

All secrets in `config/credentials.yml.enc` (encrypted):
- `secret_key_base`
- `active_record_encryption.*`
- `tiktok.app_key`, `tiktok.app_secret`, `tiktok.redirect_uri`
- `anthropic.api_key`

Master key: `config/master.key` (not committed)

## Key files

- `docs/PLAN.md` — master build plan with 13 phases
- `docs/TIKTOK_API_NOTES.md` — signing algorithm, endpoint conventions, gotchas
- `docs/SPARK_CODE_NOTES.md` — Spark Ads follow-up flow
- `config/tiktok_banned_keywords.yml` — curated moderation keyword list
- `config/recurring.yml` — Solid Queue scheduled jobs
