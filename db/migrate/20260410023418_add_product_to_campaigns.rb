class AddProductToCampaigns < ActiveRecord::Migration[8.1]
  # Campaigns table has no data yet — safe to add NOT NULL without a backfill.
  def change
    add_reference :campaigns, :product, null: false, foreign_key: true
  end
end
