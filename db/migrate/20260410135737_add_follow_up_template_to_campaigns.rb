class AddFollowUpTemplateToCampaigns < ActiveRecord::Migration[8.1]
  def change
    add_column :campaigns, :follow_up_template, :text
  end
end
