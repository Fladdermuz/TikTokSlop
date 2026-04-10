class AddShopScopingToTenantTables < ActiveRecord::Migration[8.1]
  # Tenant tables hold no data yet (asserted before this migration was written),
  # so we add NOT NULL shop_id directly without a backfill step.
  def change
    # tiktok_tokens — the existing shop_id column held TikTok's external shop ID,
    # not our internal Shop FK. Rename to external_shop_id and drop its index.
    remove_index :tiktok_tokens, :shop_id
    rename_column :tiktok_tokens, :shop_id, :external_shop_id
    add_index :tiktok_tokens, :external_shop_id

    add_reference :tiktok_tokens, :shop, null: false, foreign_key: true, index: { unique: true }
    add_reference :campaigns,     :shop, null: false, foreign_key: true
    add_reference :invites,       :shop, null: false, foreign_key: true
    add_reference :samples,       :shop, null: false, foreign_key: true
  end
end
