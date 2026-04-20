class AddCommissionAbTestToCampaigns < ActiveRecord::Migration[8.1]
  def change
    add_column :campaigns, :ab_test_enabled,   :boolean, default: false, null: false
    add_column :campaigns, :commission_rate_b, :decimal, precision: 6, scale: 4
    add_column :campaigns, :cohort_b_split_pct, :integer, default: 50, null: false
  end
end
