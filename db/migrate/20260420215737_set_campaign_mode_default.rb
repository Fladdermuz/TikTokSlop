class SetCampaignModeDefault < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE campaigns SET mode = 'target' WHERE mode IS NULL"
    change_column_default :campaigns, :mode, "target"
    change_column_null :campaigns, :mode, false
    add_index :campaigns, :mode
  end

  def down
    remove_index :campaigns, :mode
    change_column_null :campaigns, :mode, true
    change_column_default :campaigns, :mode, nil
  end
end
