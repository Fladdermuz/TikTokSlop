class CreateAffiliateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :affiliate_orders do |t|
      t.timestamps
    end
  end
end
