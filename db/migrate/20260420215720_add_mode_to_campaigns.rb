class AddModeToCampaigns < ActiveRecord::Migration[8.1]
  def change
    add_column :campaigns, :mode, :string
  end
end
