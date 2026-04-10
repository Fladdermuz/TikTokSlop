class CreateCampaigns < ActiveRecord::Migration[8.1]
  def change
    create_table :campaigns do |t|
      t.string :name, null: false
      t.string :external_id
      t.string :product_external_id
      t.decimal :commission_rate, precision: 6, scale: 4
      t.boolean :sample_offer, default: false, null: false
      t.string :status, default: "draft", null: false
      t.text :message_template
      t.text :notes

      t.timestamps
    end
    add_index :campaigns, :external_id, unique: true, where: "external_id IS NOT NULL"
    add_index :campaigns, :status
  end
end
