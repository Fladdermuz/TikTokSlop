class CreateSamples < ActiveRecord::Migration[8.1]
  def change
    create_table :samples do |t|
      t.references :invite, null: false, foreign_key: true
      t.string :external_id
      t.string :status, default: "requested", null: false
      t.string :tracking_number
      t.string :carrier
      t.datetime :shipped_at
      t.datetime :delivered_at
      t.jsonb :raw, default: {}, null: false

      t.timestamps
    end
    add_index :samples, :status
    add_index :samples, :external_id, unique: true, where: "external_id IS NOT NULL"
  end
end
