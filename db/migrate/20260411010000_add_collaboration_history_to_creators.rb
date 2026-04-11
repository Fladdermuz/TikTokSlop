class AddCollaborationHistoryToCreators < ActiveRecord::Migration[8.1]
  def change
    add_column :creators, :collaboration_history, :jsonb, default: [], null: false
  end
end
