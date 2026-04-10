class CreateTiktokTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :tiktok_tokens do |t|
      t.string :shop_id, null: false
      t.string :shop_cipher
      t.string :shop_name
      t.string :seller_name
      t.text :access_token, null: false
      t.text :refresh_token, null: false
      t.datetime :access_expires_at, null: false
      t.datetime :refresh_expires_at, null: false
      t.text :scopes

      t.timestamps
    end
    add_index :tiktok_tokens, :shop_id, unique: true
  end
end
