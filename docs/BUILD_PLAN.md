# Tikedon Build Plan — Unused API Capabilities

This document inventories what's in the TikTok Shop API surface that Tikedon has resource methods for but doesn't yet exercise end-to-end, ranked by value. Use this when deciding what to build next.

Generated: 2026-04-21

---

## Audit snapshot

| Scope | Resource file | Live callsites | Coverage |
|---|---|---|---|
| `seller.finance.info` (Active) | `finance.rb` (6 methods) | `FinanceController` | Fully covered ✅ |
| `seller.affiliate_collaboration.write` (Under review) | `affiliate_collaboration.rb` (11 methods) | 7 jobs + controllers + model hooks | Fully covered ✅ (just built) |
| `seller.creator_marketplace.read` (Under review) | `affiliate_creator.rb` (3 methods) | `CreatorSearch` service | Fully covered ✅ |
| `seller.affiliate_messages.write` (Awaiting submission) | `message.rb` (5 methods) | `SendSampleFollowUpJob` only | Partial — only Spark Code follow-up uses IM send |
| `seller.affiliate_collaboration.read` | `affiliate_collaboration.rb` + `affiliate_sample.rb` | Some read methods used for sample eligibility | Partial — affiliate-order read unused |
| `seller.product.basic` (Awaiting) | `product.rb` (2 methods) | `SyncProductsJob` | Partial — editor/validator endpoints unused |
| `seller.shop.info` (Awaiting) | `shop.rb` (1 method) | OAuth callback only | Partial — warehouse/permissions unused |
| `seller.authorization.info` / webhooks (Awaiting) | `authorization.rb` + `webhook.rb` | `authorization.rb` live; `webhook.rb` zero | Webhook management **completely unused** |
| `data.shop_analytics.public.read` (Awaiting) | `analytics.rb` (7 methods) | **Zero live callsites** | **Completely unused** |
| `seller.order.info` (Awaiting, SENSITIVE) | _no resource file_ | — | **Completely unbuilt** |
| `seller.fulfillment.basic` (Awaiting) | _no resource file_ | — | **Completely unbuilt** |
| `seller.logistics` (Awaiting) | _no resource file_ | — | **Completely unbuilt** |

---

## Build priority

### Tier 1 — highest value (build first)

1. **Shop Video Performance analytics** — `data.shop_analytics.public.read`
    - The answer to "what's the affiliate post rate?"
    - `Get Shop Video Performance List` returns every video tied to your shop's products, who made it, views, conversions.
    - Resource methods already exist in `analytics.rb`.
    - Build: `CreatorVideo` model + sync job + per-creator leaderboard UI.

2. **Affiliate order attribution dashboard** — `seller.affiliate_collaboration.read`
    - Per-creator ROI: which creator actually drove which orders, which campaigns have real return, which creators are worth doubling down on.
    - `Search Seller Affiliate Orders` already on `AffiliateCollaboration#search_affiliate_orders`.
    - Build: `AffiliateOrder` model + sync job + attribution on creator detail page + new ROI slice by creator.

### Tier 2 — high value

3. **Full creator inbox** — `seller.affiliate_messages.write`
    - List conversations, read/reply to creator DMs inside Tikedon instead of switching to Seller Center.
    - Build: inbox view, per-conversation view, unread badge on nav.

4. **Webhook subscription management** — `seller.authorization.info`
    - Replace polling (invite status, sample status) with real-time event delivery.
    - Lower API burn, faster UI updates.
    - Build: webhook registration on OAuth connect, webhook controller to receive events, event handlers per topic.

5. **Orders + attribution** — `seller.order.info`
    - Complements #2 — get the actual order records (customer-ish data, line items) for the orders `Search Seller Affiliate Orders` returns.
    - Sensitive scope; only fetch what's needed, don't store customer PII beyond what the product requires.

### Tier 3 — medium value

6. **Sample fulfillment automation** — `seller.fulfillment.basic` + `seller.logistics`
    - Print labels, schedule pickups, mark shipped from inside Tikedon.
    - Needs new resource files (`fulfillment.rb`, `logistics.rb`).

7. **Product editor** — `seller.product.basic` additional endpoints
    - In-app product creation/edit instead of Seller Center.
    - Nice-to-have; not pressing.

---

## What gets built in the current work session

**Tier 1 items — both.**

Each will follow the same recipe we used for the affiliate-collaboration work:

1. Add the DB model + migration to cache the data locally (we never hit TikTok on page render).
2. Add a background sync job that fetches from TikTok and upserts.
3. Add a recurring schedule entry so the sync runs on its own.
4. Build the UI.
5. Add seeded demo data so the UI isn't empty during scope review.

This matches the pattern that gets pages populated enough to show a reviewer, without requiring live TikTok data.
