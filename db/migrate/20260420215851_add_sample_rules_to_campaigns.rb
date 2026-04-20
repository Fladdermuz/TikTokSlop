class AddSampleRulesToCampaigns < ActiveRecord::Migration[8.1]
  def change
    add_column :campaigns, :max_samples_per_creator,       :integer
    add_column :campaigns, :sample_valid_days,             :integer
    add_column :campaigns, :sample_min_follower_threshold, :integer
  end
end
