class AddShowcaseToCreators < ActiveRecord::Migration[8.1]
  def change
    add_column :creators, :showcase_products, :jsonb, default: [], null: false
    add_column :creators, :brand_partnerships, :jsonb, default: [], null: false
  end
end
