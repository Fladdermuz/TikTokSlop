class CreateInvites < ActiveRecord::Migration[8.1]
  def change
    create_table :invites do |t|
      t.references :creator, null: false, foreign_key: true
      t.references :campaign, null: false, foreign_key: true
      t.string :external_id
      t.string :status, default: "pending", null: false
      t.text :message
      t.datetime :sent_at
      t.datetime :responded_at
      t.text :error_message
      t.integer :retry_count, default: 0, null: false
      t.jsonb :raw, default: {}, null: false

      t.timestamps
    end
    add_index :invites, :status
    add_index :invites, :external_id, unique: true, where: "external_id IS NOT NULL"
    add_index :invites, [ :creator_id, :campaign_id ], unique: true
  end
end
