class CreateAiUsageLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_usage_logs do |t|
      t.references :shop, null: false, foreign_key: true
      t.string :feature, null: false     # "moderation" | "crafter_template" | "crafter_personalized" | "failure_analysis" | "other"
      t.string :model, null: false
      t.integer :input_tokens,  default: 0, null: false
      t.integer :output_tokens, default: 0, null: false
      t.integer :cost_cents,    default: 0, null: false
      t.string :request_id

      t.timestamps
    end
    add_index :ai_usage_logs, [ :shop_id, :created_at ]
    add_index :ai_usage_logs, [ :shop_id, :feature ]
  end
end
