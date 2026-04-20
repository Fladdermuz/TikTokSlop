# TikTok Shop API Scopes — Tikedon

**App Key**: `6jivv5jtl3fu5`
**Service ID**: `7627044612074800909`

## Activated Scopes

| # | Scope Name | Scope ID | Scope Key | Status | Notes |
|---|---|---|---|---|---|
| 1 | Affiliate Information | 434372 | `creator.affiliate.info` | Under review | Creator search, GMV, engagement data |
| 2 | Finance Information | 430596 | `seller.finance.info` | Active | Commission and revenue reporting |
| 3 | Fulfillment Basic | 430340 | `seller.fulfillment.basic` | Awaiting submission | Sample/package tracking |
| 4 | Global Shop Information | 431300 | `seller.shop.info` | Awaiting submission | Shop_cipher for API calls |
| 5 | Logistics Basic | 430404 | `seller.logistics` | Awaiting submission | Shipping/tracking info |
| 6 | Manage Affiliate Messages | 1897028 | `seller.affiliate_messages.write` | Awaiting submission | Send follow-up messages, IM messaging |
| 7 | Manage Seller Affiliate Collaboration | 890884 | `seller.affiliate_collaboration.write` | Under review | Create/manage targeted + open collaborations |
| 8 | Order Information | 430276 | `seller.order.info` | Awaiting submission (SENSITIVE) | Order details, delivery status |
| 9 | Product Basic | 430148 | `seller.product.basic` | Awaiting submission | Read/manage product catalog |
| 10 | Read Creator Marketplace | 925572 | `seller.creator_marketplace.read` | Under review | Creator search by GMV/followers/category |
| 11 | Read Seller Affiliate Collaboration | 733764 | `seller.affiliate_collaboration.read` | Under review | Read collab status, samples, orders |
| 12 | Shop Authorized Information | 431812 | `seller.authorization.info` | Awaiting submission | OAuth flow, webhooks |
| 13 | TikTok Shop Analytics | 948484 | `data.shop_analytics.public.read` | Awaiting submission | Shop/product/video/LIVE performance metrics |
| 14 | Read Creator Affiliate Collaborations | 1021508 | `creator.affiliate_collaboration.read` | Under review | Creator collab history, sample apps, affiliate orders |
| 15 | Read Showcase Products | 791236 | `creator.showcase.read` | Under review | Creator showcase product list |

## Skipped Scopes

Everything else (Global Product CRUD, Promotions, all Partner/TAP scopes — we are a seller not a partner —, FBT, Package Split, External Order References, Delivery Status Write, Product Optimization, Image Translation, Redeem Info).

## Scope Details (updated as we activate each one)

### Affiliate Information
- **Scope ID**: 434372
- **Scope Key**: `creator.affiliate.info`
- **Status**: Under review
- **Used by**: `Tiktok::Resources::AffiliateCreator` — creator search, profile data

### Finance Information
- **Scope ID**: 430596
- **Scope Key**: `seller.finance.info`
- **Status**: Active
- **Used by**: Dashboard analytics, commission reporting
- **Endpoints**:
  - Get Payments — automated payment records by date range. *Unavailable in SEA markets.*
  - Get Statements — daily statements by date range or payment status. Data after 2023-07-01 only.
  - Get Transactions by Order — order-level + SKU-level transactions (sales, fees, commissions, shipping, taxes, adjustments, refunds). *US and UK only.*
  - Get Transactions by Statement — transactions by statement_id. *US and UK only.*
  - Get Unsettled Transactions — unsettled orders + adjustments. Transactions after 2025-01-01 only. Amounts are estimates until settled.
  - Get Withdrawals — seller withdrawal records by date range.

### Fulfillment Basic
- **Scope ID**: 430340
- **Scope Key**: `seller.fulfillment.basic`
- **Status**: Awaiting submission
- **Used by**: Sample fulfillment tracking, package status monitoring
- **Endpoints**:
  - Batch Ship Packages — batch ship by providing multiple package IDs. Works for TikTok Shipping (schedule pickup) and Seller Shipping (upload tracking number + provider).
  - Confirm Package Shipment — warehouse service provider sends shipment info. *Certified warehouse providers only.*
  - Create First Mile Bundle — create a first-mile bundle when sending multiple packages to TikTok Shop warehouse.
  - Create First Mile Bundle (V2) — same as above, newer version.
  - Create Last Mile Bundle — inform TTS platform about a last mile bundle shipment.
  - Create Packages — ship orders / purchase labels. *US only.* Shipping fee and delivery time are estimates.
  - Create Return — initiate return request on behalf of buyer. Options: return & refund, returnless refund, partial refund.
  - Fulfillment Upload Delivery File — upload proof of delivery (PDF, max 10MB). *SOF (Seller Own Fleet) only.*
  - Fulfillment Upload Delivery Image — upload proof of delivery image (JPEG/PNG/JPG, max 5MB). Used with Update Package Delivery Status.
  - Get Eligible Shipping Service — query available shipping services by package size/weight. *US and JP.*
  - Get Handover Time Slots — retrieve pickup/drop-off/van collection time slots for a package.
  - Get Package Detail — package info including handover time slot, tracking number, shipping provider.
  - Get Package Shipping Document — retrieve shipping label and packing slip URL. *TikTok Shipping orders only.* Must call Ship Package first.
  - Get Shipping Providers — get shipping provider for a specified delivery option.
  - Mark Package As Shipped — upload package info (items, shipping provider, tracking number) for seller-fulfilled orders. *US, UK, ES, IE, IT, DE, FR, JP.*
  - Schedule Package Handover — schedule pickup or drop-off for platform shipping. Uses order ID.
  - Search Package — retrieve package IDs by creation time or update time.
  - Ship Package — ship a package via TikTok Shipping (schedule pickup) or Seller Shipping (upload tracking + provider). Package ID from Get Order Detail.
  - Update Package Shipping Info — update tracking number and shipping provider for already-shipped packages. *Seller-shipped orders only.*
  - Upload Invoice — upload invoice document. *Brazil market only.*

### Global Shop Information
- **Scope ID**: 431300
- **Scope Key**: `seller.shop.info`
- **Status**: Awaiting submission
- **Used by**: `Tiktok::Resources::Shop` — get shop_cipher and shop name after OAuth
- **Endpoints**:
  - Get Active Shops — retrieves all active shops belonging to a seller. Check activation status.
  - Get Global Seller Warehouse — retrieves all global warehouse info (ID, name, ownership).
  - Get Seller Permissions — check cross-border seller permissions for listing global products. *Cross-border sellers only.*

### Logistics Basic
- **Scope ID**: 430404
- **Scope Key**: `seller.logistics`
- **Status**: Awaiting submission
- **Used by**: Sample shipping/tracking info, delivery monitoring
- **Endpoints**:
  - Get Available Shipping Template — seller's available shipping templates + reasons if unavailable.
  - Get Shipping Providers — get shipping provider for a specified delivery option.
  - Get Tracking — get logistics tracking information by order number.
  - Get Warehouse Delivery Options — list of delivery options available through seller's designated warehouse.
  - Get Warehouse List — all warehouse info (name, status, address, details).
  - TTS Tracking Validation — validate whether a tracking number is covered by TikTok Shipping or Collection by TikTok. *US only.*
  - Update Shipping Info — update tracking number and shipping provider for already-shipped orders.

### Manage Affiliate Messages
- **Scope ID**: 1897028
- **Scope Key**: `seller.affiliate_messages.write`
- **Status**: Awaiting submission
- **Used by**: `Tiktok::SendSampleFollowUpJob` — Spark Code follow-ups, `Tiktok::SendInviteJob` — outreach messages
- **Endpoints**:
  - Create Conversation with Creator — get existing or create new conversation with a TikTok creator.
  - Get Conversation List — list user's conversations.
  - Get Latest Unread Messages — unread messages from the last minute. Webhook recommended for real-time.
  - Get Message in the Conversation — chat history for one conversation.
  - Mark Conversation Read — mark messages in specified conversations as read.
  - Send IM Message — send an instant message to a creator.
  - Upload Message Image — upload image before sending as a message via Send IM Message.

### Manage Seller Affiliate Collaboration
- **Scope ID**: 890884
- **Scope Key**: `seller.affiliate_collaboration.write`
- **Status**: Under review
- **Used by**: `Tiktok::Resources::AffiliateCollaboration` — creating targeted + open collaborations
- **Endpoints**:
  - Create Open Collaboration — create open collab by selecting products + setting commission rate.
  - Create Target Collaboration — create private collab with specific products + commission + invited creators. Not visible in Creator Marketplace, only to invited creators.
  - Edit Open Collaboration Sample Rule — manage sample rules (valid periods, thresholds for creator sample requests). Create/update/deactivate rules.
  - Edit Open Collaboration Settings — enroll product catalog into open collaboration plan. Default off for all sellers.
  - Generate Affiliate Product Promotion Link — generate product-level affiliate link for open collaboration products. Attributed to partner.
  - Generate Target Collaboration Link — shareable link for creator to review and accept a target collaboration.
  - Remove Creator From Open Collaboration — remove creator. Note: creators can rejoin after removal.
  - Remove Open Collaboration — terminate open collab for a product. Not immediate — delayed to protect creator interests.
  - Remove Target Collaboration — seller removes a target collaboration.
  - Seller Review Sample Applications — approve/reject creator sample requests in open collaborations. Rejection requires a reason.
  - Update Target Collaboration — update a standard target collaboration.

### Order Information (SENSITIVE)
- **Scope ID**: 430276
- **Scope Key**: `seller.order.info`
- **Status**: Awaiting submission
- **Sensitive data**: Yes — contains customer PII (shipping addresses, payment details)
- **Used by**: `Tiktok::SyncSampleStatusJob` — tracking sample order delivery status
- **Data protection measures**:
  - We only read order status and delivery timestamps — we do NOT store customer shipping addresses, payment details, or buyer PII in our database
  - TikTok OAuth tokens are encrypted at rest (Rails ActiveRecord encryption)
  - All API calls are server-side only — no client-side token exposure
  - Multi-tenant isolation ensures one shop cannot access another shop's order data
  - HTTPS enforced on all connections
  - Privacy policy at tikedon.com/privacy discloses data handling
- **Endpoints**:
  - Get Order Detail — order status, shipping addresses, payment, price/tax, package info.
  - Get Order List — orders by creation/update timeframe with filtering (status, delivery option, buyer ID).
  - Get Price Detail — detailed pricing breakdown including vouchers, tax.

### Product Basic
- **Scope ID**: 430148
- **Scope Key**: `seller.product.basic`
- **Status**: Awaiting submission
- **Used by**: Product sync for campaigns, product knowledge base import
- **Endpoints**:
  - Activate Product — activate hidden products (Seller_deactivated/Platform_deactivated), sends to audit.
  - Check Listing Prerequisites — get product rules and whether listing prerequisites are met.
  - Check Product Listing — pre-check product properties before listing to catch issues.
  - Create Custom Brands — create custom brands (up to 50/day, 1000 total).
  - Create Category Upgrade Task — upgrade products from 3-level to 7-level category tree.
  - Deactivate Products — hide products from buyers (status → Seller_deactivated).
  - Get Attributes — product and sales attributes for a category (mandatory vs optional).
  - Get Brands — all available brands for shop (built-in + custom), authorization status.
  - Get Categories — product category list. Call in real-time, don't cache.
  - Get Category Rules — additional listing requirements (certifications, size charts, dimensions).
  - Get Global Listing Rules — listing rules for global sellers.
  - Get Global Replicated Products — globally associated replicas. Global sellers only.
  - Get Product — retrieve all properties of a product (except FREEZE/DELETED).
  - Get Products SEO Words — SEO suggestions for product titles. *US, UK, SEA only.*
  - Inventory Search — inventory info for multiple products/SKUs.
  - Listing Schemas — field requirements for creating a product by leaf category.
  - Optimized Images — change product image backgrounds to white.
  - Recommend Category — get recommended category from title/description/images.
  - Search Products — list products by conditions, returns key properties.
  - Upload Product File — upload PDF/video for product listings.
  - Upload Product Image — upload images for product use.

### Read Creator Marketplace
- **Scope ID**: 925572
- **Scope Key**: `seller.creator_marketplace.read`
- **Status**: Under review
- **Used by**: `Tiktok::CreatorSearch`, `Tiktok::Resources::AffiliateCreator` — creator discovery dashboard
- **Endpoints**:
  - Get Marketplace Creator Performance — creator's marketplace info and performance metrics (last 30 days).
  - Get Seller Search Creator Marketplace Advanced Filters — retrieve latest available search filters by country/region. Filters update dynamically.
  - Seller Search Creator on Marketplace — search creators by GMV, keywords, follower demographics. All data is last 30 days.

### Read Seller Affiliate Collaboration
- **Scope ID**: 733764
- **Scope Key**: `seller.affiliate_collaboration.read`
- **Status**: Under review
- **Used by**: `Tiktok::SyncInviteStatusJob`, `Tiktok::SyncSampleStatusJob`, dashboard analytics
- **Endpoints**:
  - Create Compass Offline Export Task — async export task for specified doc/plan type within time window.
  - Download Compass Task File — download completed export task result file.
  - Get Compass Task List — list export tasks from last 7 days with pagination.
  - Get Open Collaboration Creator Content Detail — creator content details for a specific open collaboration.
  - Get Open Collaboration Sample Rules — sample rule status/details for products in open collaboration.
  - Get Open Collaboration Settings — open collaboration settings including auto-add.
  - Query Target Collaboration Detail — get target collaboration information.
  - Search Open Collaboration — all open collaboration info (commission rate, showcase/content creator count).
  - Search Seller Affiliate Orders — retrieve affiliate-commission-eligible orders by seller. Track conversions.
  - Search Target Collaborations — search existing target collaborations by name, ID, product, creator.
  - Seller Get Sample Request Deeplink — TikTok deeplink to sample request page. Can encode as QR code for email.
  - Seller Search Affiliate Open Collaboration Product — search open collaboration products by category/commission/keywords across regions.
  - Seller Search Sample Applications — query sample applications by product, creator, or status.
  - Seller Search Sample Applications Fulfillments — track sample application fulfillment status and whether it resulted in orders.

### Read Creator Affiliate Collaborations
- **Scope ID**: 1021508
- **Scope Key**: `creator.affiliate_collaboration.read`
- **Status**: Under review
- **Used by**: Creator detail page — collaboration history display
- **Endpoints**:
  - Creator Get Sample Request Deeplink — one-time TikTok deeplink to sample request page. Can redirect back to 3rd party app after submission.
  - Creator Search Open Collaboration Product — search open collaboration products by category/commission/keywords. Region-restricted to creator's affiliate region.
  - Creator Search Sample Application Fulfillments — query fulfillment status for received sample applications.
  - Creator Select Affiliate Product — filter products using various conditions. Returns algorithm-recommended products when no filter given.
  - Get Creator Applicable Sample Label — check if a creator can apply for a sample of a specific product.
  - Get Creator Sample Application Detail — sample detail for a specified sample application.
  - Get Open Collaboration Product List By Product Ids — get open collaboration product list by product IDs.
  - Search Creator Affiliate Orders — retrieve affiliate orders generated by a creator. Track conversions by order ID and product ID.
  - Search Creator Sample Applications — get sample application list of creator.
  - Search Creator Target Collaborations — search creator's target collaborations and products within them.

### Read Showcase Products
- **Scope ID**: 791236
- **Scope Key**: `creator.showcase.read`
- **Status**: Under review
- **Used by**: Creator detail page — showcase products grid
- **Endpoints**:
  - Read Showcase Products — retrieve products in a creator's showcase.

### Shop Authorized Information
- **Scope ID**: 431812
- **Scope Key**: `seller.authorization.info`
- **Status**: Awaiting submission
- **Used by**: OAuth flow, webhook configuration, shop management
- **Endpoints**:
  - Deauthorize Shop — deauthorize a shop and notify seller by email.
  - Delete Shop Webhook — delete webhook URL for a specific event topic.
  - Get Authorized Shops — list of shops seller has authorized for the app. Get shop cipher for API calls.
  - Get Shop Group — query product interoperability groups between shops (e.g. US + Mexico).
  - Get Shop Webhooks — retrieve shop's webhooks and URLs.
  - Get Widget Token — generate a widget token.
  - Update Shop Webhook — update webhook URL for a specific event topic.

### TikTok Shop Analytics
- **Scope ID**: 948484
- **Scope Key**: `data.shop_analytics.public.read`
- **Status**: Awaiting submission
- **Used by**: Dashboard analytics, performance reporting
- **Endpoints**:
  - Get Shop Performance — shop/seller level performance metrics.
  - Get Shop Performance Per Hour — daily hourly breakdown, within 30 days including today.
  - Get Shop Product Performance Detail — performance metrics for a single product.
  - Get Shop Product Performance List — list of product performance metrics.
  - Get Shop SKU Performance — SKU-level performance metrics.
  - Get Shop SKU Performance List — list of SKU performance metrics.
  - Get Shop Video Performance Details — detailed metrics for a specific video.
  - Get Shop Video Performance List — list of videos and metrics for a shop.
  - Get Shop Video Performance Overview — overall video performance across shop.
  - Get Shop Video Product Performance List — product performance within a specific video.
  - Get Shop LIVE Performance List — LIVE stream sessions and metrics.
  - Get Shop LIVE Performance Overview — overall LIVE performance metrics.
  - Get Shop LIVE Performance Per Minutes — minute-by-minute LIVE breakdown (after session ends). Official/marketing accounts only.
  - Get Shop LIVE Products Performance List — per-product sales performance in LIVE sessions.
