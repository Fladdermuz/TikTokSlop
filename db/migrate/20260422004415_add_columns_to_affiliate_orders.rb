class AddColumnsToAffiliateOrders < ActiveRecord::Migration[8.1]
  def change
    add_reference :affiliate_orders, :shop,     null: false, foreign_key: true
    add_reference :affiliate_orders, :creator,  null: true,  foreign_key: true
    add_reference :affiliate_orders, :invite,   null: true,  foreign_key: true
    add_reference :affiliate_orders, :campaign, null: true,  foreign_key: true
    add_reference :affiliate_orders, :product,  null: true,  foreign_key: true

    add_column :affiliate_orders, :external_id,      :string
    add_column :affiliate_orders, :order_status,     :string,  default: "pending", null: false
    add_column :affiliate_orders, :gmv_cents,        :bigint,  default: 0, null: false
    add_column :affiliate_orders, :commission_cents, :bigint,  default: 0, null: false
    add_column :affiliate_orders, :currency,         :string,  default: "USD", null: false
    add_column :affiliate_orders, :ordered_at,       :datetime
    add_column :affiliate_orders, :raw,              :jsonb,   default: {}, null: false

    add_index :affiliate_orders, :external_id, unique: true, where: "external_id IS NOT NULL"
    add_index :affiliate_orders, :ordered_at
    add_index :affiliate_orders, [ :shop_id, :ordered_at ]
    add_index :affiliate_orders, :order_status
  end
end
