class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :shop, null: false, foreign_key: true
      t.string :role, default: "member", null: false
      t.datetime :invited_at
      t.datetime :joined_at

      t.timestamps
    end
    add_index :memberships, [ :user_id, :shop_id ], unique: true
    add_index :memberships, :role
  end
end
