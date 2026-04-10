class AddPersonalizePerCreatorToCampaigns < ActiveRecord::Migration[8.1]
  def change
    add_column :campaigns, :personalize_per_creator, :boolean, default: false, null: false
  end
end
