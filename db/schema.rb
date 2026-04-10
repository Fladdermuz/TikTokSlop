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

ActiveRecord::Schema[8.1].define(version: 2026_04_10_010337) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "campaigns", force: :cascade do |t|
    t.decimal "commission_rate", precision: 6, scale: 4
    t.datetime "created_at", null: false
    t.string "external_id"
    t.text "message_template"
    t.string "name", null: false
    t.text "notes"
    t.string "product_external_id"
    t.boolean "sample_offer", default: false, null: false
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_campaigns_on_external_id", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["status"], name: "index_campaigns_on_status"
  end

  create_table "creators", force: :cascade do |t|
    t.string "avatar_url"
    t.integer "avg_views", default: 0, null: false
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
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id"], name: "index_invites_on_campaign_id"
    t.index ["creator_id", "campaign_id"], name: "index_invites_on_creator_id_and_campaign_id", unique: true
    t.index ["creator_id"], name: "index_invites_on_creator_id"
    t.index ["external_id"], name: "index_invites_on_external_id", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["status"], name: "index_invites_on_status"
  end

  create_table "samples", force: :cascade do |t|
    t.string "carrier"
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.string "external_id"
    t.bigint "invite_id", null: false
    t.jsonb "raw", default: {}, null: false
    t.datetime "shipped_at"
    t.string "status", default: "requested", null: false
    t.string "tracking_number"
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_samples_on_external_id", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["invite_id"], name: "index_samples_on_invite_id"
    t.index ["status"], name: "index_samples_on_status"
  end

  create_table "tiktok_tokens", force: :cascade do |t|
    t.datetime "access_expires_at", null: false
    t.text "access_token", null: false
    t.datetime "created_at", null: false
    t.datetime "refresh_expires_at", null: false
    t.text "refresh_token", null: false
    t.text "scopes"
    t.string "seller_name"
    t.string "shop_cipher"
    t.string "shop_id", null: false
    t.string "shop_name"
    t.datetime "updated_at", null: false
    t.index ["shop_id"], name: "index_tiktok_tokens_on_shop_id", unique: true
  end

  add_foreign_key "invites", "campaigns"
  add_foreign_key "invites", "creators"
  add_foreign_key "samples", "invites"
end
