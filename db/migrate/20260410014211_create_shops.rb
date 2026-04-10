class CreateShops < ActiveRecord::Migration[8.1]
  def change
    create_table :shops do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :plan, default: "free", null: false
      t.string :timezone, default: "UTC", null: false
      t.string :status, default: "active", null: false

      t.timestamps
    end
    add_index :shops, :slug, unique: true
    add_index :shops, :status
  end
end
