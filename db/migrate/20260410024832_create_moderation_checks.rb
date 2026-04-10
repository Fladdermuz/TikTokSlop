class CreateModerationChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :moderation_checks do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :checkable, polymorphic: true, null: false
      t.text :checked_text, null: false
      t.string :risk, null: false         # "low" | "medium" | "high" | "blocked"
      t.jsonb :issues, default: [], null: false
      t.text :suggested_rewrite
      t.jsonb :scanner_versions, default: {}, null: false

      t.timestamps
    end
    add_index :moderation_checks, [ :checkable_type, :checkable_id, :created_at ],
              name: "idx_moderation_checks_on_checkable_latest"
    add_index :moderation_checks, :risk
  end
end
