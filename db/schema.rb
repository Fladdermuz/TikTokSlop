# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_11_004307) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "ai_usage_logs", force: :cascade do |t|
    t.integer "cost_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "feature", null: false
    t.integer "input_tokens", default: 0, null: false
    t.string "model", null: false
    t.integer "output_tokens", default: 0, null: false
    t.string "request_id"
    t.bigint "shop_id", null: false
    t.datetime "updated_at", null: false
    t.index ["shop_id", "created_at"], name: "index_ai_usage_logs_on_shop_id_and_created_at"
    t.index ["shop_id", "feature"], name: "index_ai_usage_logs_on_shop_id_and_feature"
    t.index ["shop_id"], name: "index_ai_usage_logs_on_shop_id"
  end

  create_table "campaigns", force: :cascade do |t|
    t.decimal "commission_rate", precision: 6, scale: 4
    t.datetime "created_at", null: false
    t.string "external_id"
    t.text "follow_up_template"
    t.text "message_template"
    t.string "name", null: false
    t.text "notes"
    t.boolean "personalize_per_creator", default: false, null: false
    t.string "product_external_id"
    t.bigint "product_id", null: false
    t.boolean "sample_offer", default: false, null: false
    t.bigint "shop_id", null: false
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_campaigns_on_external_id", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["product_id"], name: "index_campaigns_on_product_id"
    t.index ["shop_id"], name: "index_campaigns_on_shop_id"
    t.index ["status"], name: "index_campaigns_on_status"
  end

  create_table "creators", force: :cascade do |t|
    t.string "avatar_url"
    t.integer "avg_views", default: 0, null: false
    t.jsonb "brand_partnerships", default: [], null: false
    t.string "categories", default: [], array: true
    t.string "country"
    t.datetime "created_at", null: false
    t.string "display_name"
    t.decimal "engagement_rate", precision: 6, scale: 4
    t.string "external_id", null: false
    t.integer "follower_count", default: 0, null: false
    t.bigint "gmv_cents", default: 0, null: false
    t.string "gmv_tier"
    t.string "handle"
    t.datetime "last_seen_at"
    t.jsonb "raw", default: {}, null: false
    t.jsonb "showcase_products", default: [], null: false
    t.datetime "updated_at", null: false
    t.index ["categories"], name: "index_creators_on_categories", using: :gin
    t.index ["external_id"], name: "index_creators_on_external_id", unique: true
    t.index ["follower_count"], name: "index_creators_on_follower_count"
    t.index ["gmv_cents"], name: "index_creators_on_gmv_cents"
    t.index ["gmv_tier"], name: "index_creators_on_gmv_tier"
  end

  create_table "invites", force: :cascade do |t|
    t.bigint "campaign_id", null: false
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.text "error_message"
    t.string "external_id"
    t.text "message"
    t.jsonb "raw", default: {}, null: false
    t.datetime "responded_at"
    t.integer "retry_count", default: 0, null: false
    t.datetime "sent_at"
    t.bigint "shop_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id"], name: "index_invites_on_campaign_id"
    t.index ["creator_id", "campaign_id"], name: "index_invites_on_creator_id_and_campaign_id", unique: true
    t.index ["creator_id"], name: "index_invites_on_creator_id"
    t.index ["external_id"], name: "index_invites_on_external_id", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["shop_id"], name: "index_invites_on_shop_id"
    t.index ["status"], name: "index_invites_on_status"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "invited_at"
    t.datetime "joined_at"
    t.string "role", default: "member", null: false
    t.bigint "shop_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["role"], name: "index_memberships_on_role"
    t.index ["shop_id"], name: "index_memberships_on_shop_id"
    t.index ["user_id", "shop_id"], name: "index_memberships_on_user_id_and_shop_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "moderation_checks", force: :cascade do |t|
    t.bigint "checkable_id", null: false
    t.string "checkable_type", null: false
    t.text "checked_text", null: false
    t.datetime "created_at", null: false
    t.jsonb "issues", default: [], null: false
    t.string "risk", null: false
    t.jsonb "scanner_versions", default: {}, null: false
    t.bigint "shop_id", null: false
    t.text "suggested_rewrite"
    t.datetime "updated_at", null: false
    t.index ["checkable_type", "checkable_id", "created_at"], name: "idx_moderation_checks_on_checkable_latest"
    t.index ["checkable_type", "checkable_id"], name: "index_moderation_checks_on_checkable"
    t.index ["risk"], name: "index_moderation_checks_on_risk"
    t.index ["shop_id"], name: "index_moderation_checks_on_shop_id"
  end

  create_table "product_knowledges", force: :cascade do |t|
    t.text "benefits"
    t.string "brand_name"
    t.text "brand_voice"
    t.string "certifications", default: [], array: true
    t.datetime "created_at", null: false
    t.datetime "imported_at"
    t.bigint "imported_by_id"
    t.text "ingredients"
    t.text "long_description"
    t.bigint "product_id", null: false
    t.jsonb "raw_imports", default: {}, null: false
    t.text "short_description"
    t.string "size_or_serving"
    t.string "source_urls", default: [], array: true
    t.text "target_audience"
    t.datetime "updated_at", null: false
    t.text "use_cases"
    t.text "usp"
    t.text "warnings"
    t.index ["imported_by_id"], name: "index_product_knowledges_on_imported_by_id"
    t.index ["product_id"], name: "index_product_knowledges_on_product_id", unique: true
  end

  create_table "products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.string "external_id"
    t.string "image_url"
    t.string "name", null: false
    t.bigint "price_cents", default: 0, null: false
    t.jsonb "raw", default: {}, null: false
    t.bigint "shop_id", null: false
    t.string "status", default: "active", null: false
    t.datetime "synced_at"
    t.datetime "updated_at", null: false
    t.index ["shop_id", "external_id"], name: "index_products_on_shop_id_and_external_id", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["shop_id", "status"], name: "index_products_on_shop_id_and_status"
    t.index ["shop_id"], name: "index_products_on_shop_id"
  end

  create_table "samples", force: :cascade do |t|
    t.string "carrier"
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.string "external_id"
    t.integer "follow_up_count", default: 0, null: false
    t.bigint "invite_id", null: false
    t.text "last_follow_up_message"
    t.integer "max_follow_ups", default: 3, null: false
    t.datetime "next_follow_up_at"
    t.jsonb "raw", default: {}, null: false
    t.datetime "shipped_at"
    t.bigint "shop_id", null: false
    t.string "spark_code"
    t.datetime "spark_code_received_at"
    t.string "status", default: "requested", null: false
    t.string "tracking_number"
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_samples_on_external_id", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["invite_id"], name: "index_samples_on_invite_id"
    t.index ["next_follow_up_at"], name: "index_samples_on_next_follow_up_at", where: "((next_follow_up_at IS NOT NULL) AND ((status)::text = ANY ((ARRAY['delivered'::character varying, 'follow_up_sent'::character varying])::text[])))"
    t.index ["shop_id"], name: "index_samples_on_shop_id"
    t.index ["spark_code"], name: "index_samples_on_spark_code", where: "(spark_code IS NOT NULL)"
    t.index ["status"], name: "index_samples_on_status"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "shops", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "plan", default: "free", null: false
    t.string "slug", null: false
    t.string "status", default: "active", null: false
    t.string "timezone", default: "UTC", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_shops_on_slug", unique: true
    t.index ["status"], name: "index_shops_on_status"
  end

  create_table "tiktok_tokens", force: :cascade do |t|
    t.datetime "access_expires_at", null: false
    t.text "access_token", null: false
    t.datetime "created_at", null: false
    t.string "external_shop_id", null: false
    t.datetime "refresh_expires_at", null: false
    t.text "refresh_token", null: false
    t.text "scopes"
    t.string "seller_name"
    t.string "shop_cipher"
    t.bigint "shop_id", null: false
    t.string "shop_name"
    t.datetime "updated_at", null: false
    t.index ["external_shop_id"], name: "index_tiktok_tokens_on_external_shop_id"
    t.index ["shop_id"], name: "index_tiktok_tokens_on_shop_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "name"
    t.string "password_digest", null: false
    t.boolean "platform_admin", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["platform_admin"], name: "index_users_on_platform_admin", where: "(platform_admin = true)"
  end

  add_foreign_key "ai_usage_logs", "shops"
  add_foreign_key "campaigns", "products"
  add_foreign_key "campaigns", "shops"
  add_foreign_key "invites", "campaigns"
  add_foreign_key "invites", "creators"
  add_foreign_key "invites", "shops"
  add_foreign_key "memberships", "shops"
  add_foreign_key "memberships", "users"
  add_foreign_key "moderation_checks", "shops"
  add_foreign_key "product_knowledges", "products"
  add_foreign_key "product_knowledges", "users", column: "imported_by_id"
  add_foreign_key "products", "shops"
  add_foreign_key "samples", "invites"
  add_foreign_key "samples", "shops"
  add_foreign_key "sessions", "users"
  add_foreign_key "tiktok_tokens", "shops"
end
