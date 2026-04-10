class ExpandSamplesForFollowUp < ActiveRecord::Migration[8.1]
  def change
    add_column :samples, :spark_code,             :string
    add_column :samples, :spark_code_received_at,  :datetime
    add_column :samples, :follow_up_count,         :integer, default: 0, null: false
    add_column :samples, :next_follow_up_at,       :datetime
    add_column :samples, :max_follow_ups,          :integer, default: 3, null: false
    add_column :samples, :last_follow_up_message,  :text

    add_index :samples, :next_follow_up_at, where: "next_follow_up_at IS NOT NULL AND status IN ('delivered', 'follow_up_sent')"
    add_index :samples, :spark_code, where: "spark_code IS NOT NULL"
  end
end
