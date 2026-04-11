class AddActiveCollaborationCountToCreators < ActiveRecord::Migration[8.1]
  def change
    add_column :creators, :active_collaboration_count, :integer, default: 0, null: false
  end
end
