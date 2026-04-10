class AddProfileToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :name, :string
    add_column :users, :platform_admin, :boolean, default: false, null: false
    add_index :users, :platform_admin, where: "platform_admin = true"
  end
end
