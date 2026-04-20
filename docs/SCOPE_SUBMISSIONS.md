# TikTok Shop API Scope — Submission Log

Every time a scope application is submitted or resubmitted through the TikTok Shop Partner Center, the exact submitted text is recorded here along with the outcome. Purpose: if a scope gets rejected again we can see exactly what was previously submitted and change the specific part that didn't work.

**App Key:** `6jivv5jtl3fu5`
**Service ID:** `7627044612074800909`
**App type:** Custom app

---

## Manage Seller Affiliate Collaboration — `seller.affiliate_collaboration.write`

### Submission #2 — 2026-04-20 (following rejection of #1)

**Character budget:** Partner Center resubmission form caps justification at 500 characters.

**Screenshots attached (3 total, each hitting a distinct capability in the scope):**

1. **`/shop/campaigns`** — campaign list view.
   - Visible content: 5 campaigns across statuses (Summer Collagen Creator Push — active — Collagen Peptides — 20.0% commission; Ashwagandha Stress Relief Rollout — active — 15.0%; Hydration Mix Launch Q2 — paused — 25.0%; Magnesium Sleep Reach — draft — 18.0%; Vitamin C Glow — ended — 12.0%), with sent-invite and accepted-invite counts per row.
   - Scope endpoints visually justified: `Create Target Collaboration`, `Create Open Collaboration`, `Update Target Collaboration`, `Remove Target Collaboration`, `Remove Open Collaboration`.

2. **Bulk invite flow** (reached by navigating to `/shop/creators`, selecting 4–5 creators via row checkboxes, clicking "Invite to campaign"; lands on `/shop/bulk_invites/new` with `creator_ids` preselected).
   - Visible content: the selected creators listed with handles and GMV, the active campaigns as radio options (Summer Collagen, Ashwagandha), commission rate and sample-offer info per campaign option, and the "Send N invites" submit button.
   - Scope endpoints visually justified: **`Create Target Collaboration`** (the #1 write endpoint in this scope), `Generate Target Collaboration Link`.

3. **`/shop/samples`** — sample application queue.
   - Visible content: 15 seeded samples across 7 statuses (requested, approved, shipped with tracking numbers, delivered, follow-up sent, spark-code received with codes, no-response), linked to their creators and campaigns.
   - Scope endpoints visually justified: `Seller Review Sample Applications`, `Edit Open Collaboration Sample Rule`.

**Justification text submitted (480 chars):**

> We operate multiple supplement brand TikTok Shops and invite 50+ creators per week into affiliate collaborations. This scope is what lets our app do that work: creating targeted collaborations with specific creators, configuring commission rates and sample offers per campaign, approving or rejecting incoming creator sample applications, and removing collaborations when a campaign ends. Without it every one of these actions has to be done by hand in Seller Center, per creator.

**Result:** _pending — awaiting TikTok Partner Center review_

**Earlier drafts rejected in-conversation before submission** (for reference if we need to revise again):

- _438-char jargon checklist_ — opened with "Custom app (not App Store)", listed endpoints in technical shorthand, closed with generic security boilerplate ("Tokens encrypted at rest. HTTPS enforced."). Matthew called it out as too cold/technical; the submitted text above replaced it with a human narrative.

**What to change if Submission #2 is also rejected** (so we don't repeat what was already tried):

- Do NOT re-use the 480-char narrative above verbatim — Partner Center has already seen it.
- Do NOT re-use the same three screenshots — they've already been reviewed.
- Candidate angles to try next: (a) increase the specificity of the business story (exact shop names, monthly creator-outreach volume with supporting internal metric), (b) add a loom/video walkthrough if Partner Center permits attachments beyond screenshots, (c) raise a Partner Platform help-center ticket referencing the two prior rejections and requesting human review rather than re-running the automated resubmission flow.

---

### Submission #1 — _date unknown, pre-2026-04-20_

**Result:** Rejected 2026-04-20 with boilerplate "please re-submit with more information."
**Exact text submitted:** _not recorded — pre-dates this log. Likely insufficient: we inferred from the rejection that screenshots were sparse/empty-state and the justification did not map endpoints to UI features._

---

## Affiliate Information — `creator.affiliate.info`

**Status:** Rejected 2026-04-20. **Not resubmitted** — this is a creator-authorization scope and does not match Tikedon's shop-authorization OAuth flow. The functionality we actually need (creator search + performance data for sellers) is covered by `seller.creator_marketplace.read` instead.

---

## Manage Affiliate Partner Campaigns — `partner.tap_campaign.write`

**Status:** Rejected 2026-04-20. **Not resubmitted** — this scope requires registered TikTok Affiliate Partner (TAP) status, which we do not have and are not pursuing. We are a seller, not a partner. Withdrawn from our scope request list.
