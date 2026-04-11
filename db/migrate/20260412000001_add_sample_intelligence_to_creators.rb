class AddSampleIntelligenceToCreators < ActiveRecord::Migration[8.1]
  def change
    add_column :creators, :recent_sample_requests, :jsonb, default: [], null: false
    add_column :creators, :recommended_products, :jsonb, default: [], null: false
  end
end
