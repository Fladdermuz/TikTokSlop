class CreateCreators < ActiveRecord::Migration[8.1]
  def change
    create_table :creators do |t|
      t.string :external_id, null: false
      t.string :handle
      t.string :display_name
      t.string :avatar_url
      t.integer :follower_count, default: 0, null: false
      t.integer :avg_views, default: 0, null: false
      t.decimal :engagement_rate, precision: 6, scale: 4
      t.bigint :gmv_cents, default: 0, null: false
      t.string :gmv_tier
      t.string :country
      t.string :categories, array: true, default: []
      t.datetime :last_seen_at
      t.jsonb :raw, default: {}, null: false

      t.timestamps
    end
    add_index :creators, :external_id, unique: true
    add_index :creators, :gmv_cents
    add_index :creators, :follower_count
    add_index :creators, :gmv_tier
    add_index :creators, :categories, using: :gin
  end
end
