# TikTok Shop API — Implementation Notes

Living document for non-obvious gotchas, signing details, and version-specific behavior.
Update as we discover things during development.

## Base URLs

| Environment | Base URL |
|---|---|
| Production (global) | `https://open-api.tiktokglobalshop.com` |
| Sandbox | `https://open-api-sandbox.tiktokglobalshop.com` |
| Auth (token exchange / refresh) | `https://auth.tiktok-shops.com` |

## Endpoint path format (v2 API)

Modern TikTok Shop endpoints embed the version in the path:
```
/api/<resource>/<version>/<action>
```
Example: `/api/orders/202309/get`, `/api/affiliate_creator/202405/creators/search`.

The signing algorithm operates on this **path only**, not the full URL with query string.

## Common parameters

Every signed request includes:

| Param | Where | Notes |
|---|---|---|
| `app_key` | query | Always included. Public identifier of our app. |
| `timestamp` | query | Unix seconds (not ms). 5-minute drift window. |
| `sign` | query | The HMAC output, computed last. **Excluded from canonical string.** |
| `shop_cipher` | query | TikTok's per-shop opaque ID; required for shop-scoped endpoints |
| `access_token` | header `x-tts-access-token` | Per-shop OAuth token. **Excluded from canonical string.** Newer API prefers header over query. |

## Request signing — verified algorithm

**Cross-checked against** [`tudinhacoustic/tiktok-shop`](https://github.com/tudinhacoustic/tiktok-shop) (Node) and [`EcomPHP/tiktokshop-php`](https://github.com/EcomPHP/tiktokshop-php) (PHP). Both implementations agree.

### Steps

1. Collect all query parameters EXCEPT the following (which are excluded from the canonical string):
   - `sign`
   - `access_token`
   - `x-tts-access-token`
   - `app_secret` (defensive — should never be in query anyway)
   - `token`
2. **Sort** the remaining keys in **ASCII alphabetical order** (use a byte-wise sort, not locale-aware).
3. **Concatenate** each pair as `{key}{value}` with **no separator** between pairs.
   Example: keys `app_key`, `category`, `timestamp` with values `123`, `beauty`, `1738`
   → `"app_key123categorybeautytimestamp1738"`
4. **Prepend the request path** (URI path component, no host, no query):
   → `"/api/affiliate_creator/202405/creators/search" + canonical`
5. If `Content-Type` is **not** `multipart/form-data` and method is **not** `GET`:
   **Append** the raw request body (the exact bytes that will be sent — typically `JSON.stringify(payload)`).
6. **Wrap** the result with `app_secret` on both sides:
   → `app_secret + step5_result + app_secret`
7. **HMAC-SHA256** the wrapped string using `app_secret` as the key.
8. **Hex digest, lowercase**. This becomes the `sign` query parameter.

### Pseudocode

```ruby
def sign(method:, path:, query:, body:, app_secret:)
  filtered = query.reject { |k, _| %w[sign access_token x-tts-access-token app_secret token].include?(k.to_s) }
  canonical = filtered.sort_by { |k, _| k.to_s }.map { |k, v| "#{k}#{v}" }.join
  to_sign = path + canonical
  to_sign += body if method != :get && body.present? && !multipart?
  wrapped = app_secret + to_sign + app_secret
  OpenSSL::HMAC.hexdigest("sha256", app_secret, wrapped)
end
```

### Worked example

Input:
- `app_key=12345`
- `timestamp=1700000000`
- `version=202309`
- path = `/api/orders/202309/list`
- method = GET, body = ""
- app_secret = `topsecret`

Canonical (sorted): `app_key12345timestamp1700000000version202309`
Prepended path: `/api/orders/202309/listapp_key12345timestamp1700000000version202309`
Wrapped: `topsecret/api/orders/202309/listapp_key12345timestamp1700000000version202309topsecret`
HMAC-SHA256(key=topsecret, msg=above) → 64-char lowercase hex string.

### Critical correctness notes

- **Sort is ASCII byte-wise, NOT locale-aware.** PHP's `ksort` and Ruby's default `sort_by` on strings both do byte-wise. JS `localeCompare` is wrong and only works for ASCII keys (which is what we have).
- **Body is the raw bytes that go on the wire.** If you pretty-print JSON one place and minify another, signing will fail. Always serialize once and reuse the exact same bytes.
- **Timestamp is seconds, not milliseconds.** 5-minute drift window before TikTok rejects.
- **`shop_cipher` IS included in the signing** (it's a normal query param, not in the exclusion list).
- **Hex digest is lowercase.** PHP `hash_hmac` and Node `digest('hex')` both return lowercase. Ruby `OpenSSL::HMAC.hexdigest` also returns lowercase.

## Authentication endpoints (do not require signing)

Token exchange and refresh use the auth host and a different scheme:

```
GET https://auth.tiktok-shops.com/api/v2/token/get
  ?app_key=...
  &app_secret=...
  &auth_code=...
  &grant_type=authorized_code
```

```
GET https://auth.tiktok-shops.com/api/v2/token/refresh
  ?app_key=...
  &app_secret=...
  &refresh_token=...
  &grant_type=refresh_token
```

These endpoints take `app_secret` as a query param (the only place we send it in plaintext over the wire — it's HTTPS, but still). They do NOT require the `sign` param.

## Response shape

All TikTok Shop API responses follow:

```json
{
  "code": 0,
  "message": "Success",
  "request_id": "20240101000000000000000000000000",
  "data": { ... }
}
```

- `code: 0` is success
- Non-zero codes indicate errors. Common codes:
  - `36004004` — invalid access token
  - `35004004` — token expired
  - `12004001` — rate limit exceeded
  - `36004008` — shop_cipher mismatch
- `request_id` should be logged in our error tracker for support escalation.

## Token lifetimes

- Access token: typically 7 days (TTL in seconds, returned as `access_token_expire_in`)
- Refresh token: typically 365 days (`refresh_token_expire_in`)
- Refresh **eagerly** with a 30-minute buffer. Don't wait for the call to fail.

## Rate limits

TikTok publishes per-app and per-shop rate limits per endpoint. Headers returned with each call:

- `X-Rate-Limit-Limit` — total quota
- `X-Rate-Limit-Remaining` — remaining
- `X-Rate-Limit-Reset` — Unix seconds when the window resets

Per-shop affiliate endpoints are typically 10–20 requests/second. Conservative starting point: cap at 5/sec/shop, scale up if observed.

## Verified endpoint paths (from Partner Center scope documentation)

All paths use the v2 format: `/api/<resource>/<version>/<action>`.
POST unless noted otherwise. All shop-scoped endpoints require `shop_cipher` as a query param.

### Creator Marketplace — `seller.creator_marketplace.read`
| Endpoint | Path |
|---|---|
| Seller Search Creator on Marketplace | `/api/affiliate_creator/202405/marketplace_creators/search` |
| Get Marketplace Creator Performance | `/api/affiliate_creator/202405/marketplace_creators/performance/get` |
| Get Seller Search Creator Marketplace Advanced Filters | `/api/affiliate_creator/202405/marketplace_creators/search_filters/get` |

### Target Collaborations — `seller.affiliate_collaboration.write` + `.read`
| Endpoint | Path | Scope |
|---|---|---|
| Create Target Collaboration | `/api/affiliate_seller/202405/target_collaborations/create` | write |
| Update Target Collaboration | `/api/affiliate_seller/202405/target_collaborations/update` | write |
| Remove Target Collaboration | `/api/affiliate_seller/202405/target_collaborations/remove` | write |
| Generate Target Collaboration Link | `/api/affiliate_seller/202405/target_collaborations/link/generate` | write |
| Search Target Collaborations | `/api/affiliate_seller/202405/target_collaborations/search` | read |
| Query Target Collaboration Detail | `/api/affiliate_seller/202405/target_collaborations/get` | read |

### Sample Applications — `seller.affiliate_collaboration.read` + `.write`
| Endpoint | Path | Scope |
|---|---|---|
| Seller Search Sample Applications | `/api/affiliate_seller/202405/sample_applications/search` | read |
| Seller Search Sample Applications Fulfillments | `/api/affiliate_seller/202405/sample_applications/fulfillments/search` | read |
| Seller Review Sample Applications | `/api/affiliate_seller/202405/sample_applications/review` | write |
| Seller Get Sample Request Deeplink | `/api/affiliate_seller/202405/sample_applications/deeplink/get` | read |

### Messaging — `seller.affiliate_messages.write`
| Endpoint | Path |
|---|---|
| Create Conversation with Creator | `/api/affiliate_seller/202405/conversations/create` |
| Send IM Message | `/api/affiliate_seller/202405/messages/send` |
| Get Conversation List | `/api/affiliate_seller/202405/conversations/list` |
| Get Message in the Conversation | `/api/affiliate_seller/202405/conversations/messages/get` |
| Mark Conversation Read | `/api/affiliate_seller/202405/conversations/read` |

### Shop — `seller.shop.info`
| Endpoint | Path | Method |
|---|---|---|
| Get Active Shops | `/api/seller/202309/shops/get_active` | GET |

### Products — `seller.product.basic`
| Endpoint | Path | Method |
|---|---|---|
| Search Products | `/api/products/202309/search` | POST |
| Get Product | `/api/products/202309/products/{product_id}` | GET |

## Things still TBD

- Shape of the targeted collaboration request body (varies by 2024xx vs 2025xx version)
- Whether webhook delivery is available for invite/sample status changes (would let us drop polling)
- Exact request/response body shapes for messaging endpoints (need live testing)
