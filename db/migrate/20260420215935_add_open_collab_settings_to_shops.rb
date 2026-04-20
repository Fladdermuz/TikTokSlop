class AddOpenCollabSettingsToShops < ActiveRecord::Migration[8.1]
  def change
    add_column :shops, :open_collab_auto_add, :boolean, default: false, null: false
    add_column :shops, :open_collab_default_commission_rate, :decimal, precision: 6, scale: 4
  end
end
