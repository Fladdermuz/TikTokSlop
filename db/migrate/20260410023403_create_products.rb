class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.references :shop, null: false, foreign_key: true
      t.string :external_id
      t.string :name, null: false
      t.string :image_url
      t.bigint :price_cents, default: 0, null: false
      t.string :currency, default: "USD", null: false
      t.string :status, default: "active", null: false
      t.datetime :synced_at
      t.jsonb :raw, default: {}, null: false

      t.timestamps
    end
    add_index :products, [ :shop_id, :external_id ], unique: true, where: "external_id IS NOT NULL"
    add_index :products, [ :shop_id, :status ]
  end
end
