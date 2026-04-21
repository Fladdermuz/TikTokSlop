class DropCreatorIntelligenceColumns < ActiveRecord::Migration[8.1]
  # These columns were populated from creator-authorization scopes
  # (creator.showcase.read, creator.affiliate_collaboration.read) that were
  # permanently denied for our shop-authorization app. Dropping them along
  # with the UI sections that displayed them.
  #
  # active_collaboration_count is intentionally kept — it is computed
  # locally from our own invites table, not from a creator-scope endpoint.
  def change
    remove_column :creators, :showcase_products,      :jsonb, default: [], null: false
    remove_column :creators, :brand_partnerships,     :jsonb, default: [], null: false
    remove_column :creators, :collaboration_history,  :jsonb, default: [], null: false
    remove_column :creators, :recent_sample_requests, :jsonb, default: [], null: false
    remove_column :creators, :recommended_products,   :jsonb, default: [], null: false
  end
end
