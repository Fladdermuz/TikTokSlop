# Spark Ads + Sample Follow-up Flow

## What is a Spark Code?

When a creator posts a video featuring your product on TikTok, they can generate a
**Spark Ads authorization code** (also called a "Spark Code"). This code lets the
seller (you) boost the creator's organic video as a paid ad — which performs way
better than seller-produced creative because it's authentic.

The Spark Code is a string the creator generates from their TikTok app:
`Settings → Creator tools → TikTok Shop → Spark Ads → Generate code`

## The flow Tikedon needs to automate

```
Invite accepted
    ↓
Sample shipped → Sample delivered
    ↓
Wait X days (configurable, default 5)
    ↓
Auto-send follow-up message: "Hey! Hope you loved the [product].
    If you've posted a video, could you share the Spark Ads code?
    Here's how: [instructions link]"
    ↓
Creator replies with code → we capture it
    ↓
(Future: auto-import into TikTok Ads Manager via API)
```

## Implementation in Tikedon

### Sample status machine (updated)
```
requested → approved → shipped → delivered → follow_up_sent → spark_code_received
                                                             → no_response (terminal after X follow-ups)
Also: rejected | returned (terminal negative at any point)
```

### New fields on Sample
- `spark_code` (string) — the code the creator sends back
- `spark_code_received_at` (datetime)
- `follow_up_count` (integer, default 0) — how many follow-ups sent
- `next_follow_up_at` (datetime) — when to send the next one
- `max_follow_ups` (integer, default 3) — configurable per campaign

### Follow-up message template
Configurable per campaign (like the invite template). Default:
```
Hey {{creator.handle}}! Hope you're loving the {{product.name}} 🙌

If you've had a chance to create content with it, we'd love to boost your
video as a Spark Ad! Could you share the Spark Ads authorization code?

Here's how to generate it:
1. Open TikTok → tap your profile
2. Go to Creator tools → TikTok Shop
3. Find the video → Spark Ads → Generate code
4. Copy and send it back here!

The code helps us run your video as a paid ad, which means more views
for your content too. Thanks!
```

### Jobs
- `Tiktok::SendSampleFollowUpJob` — sends the follow-up message to creators
  whose samples are `delivered` and `next_follow_up_at <= now`
- `Tiktok::ScanForFollowUpsJob` — recurring (every 2 hours), finds samples
  needing follow-up, enqueues per-sample jobs
- Follow-up messages go through the same moderation pipeline as invites

### Spark code capture
- Manual entry in the UI (invite detail or sample detail page)
- Future: parse incoming TikTok messages for codes matching the Spark format
