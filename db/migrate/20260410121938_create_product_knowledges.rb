class CreateProductKnowledges < ActiveRecord::Migration[8.1]
  def change
    create_table :product_knowledges do |t|
      t.references :product, null: false, foreign_key: true, index: { unique: true }
      t.text :short_description
      t.text :long_description
      t.text :ingredients
      t.text :benefits
      t.text :target_audience
      t.text :use_cases
      t.text :usp
      t.string :brand_name
      t.text :brand_voice
      t.string :size_or_serving
      t.text :warnings
      t.string :certifications, array: true, default: []
      t.string :source_urls, array: true, default: []
      t.references :imported_by, null: true, foreign_key: { to_table: :users }
      t.datetime :imported_at
      t.jsonb :raw_imports, default: {}, null: false

      t.timestamps
    end
  end
end
