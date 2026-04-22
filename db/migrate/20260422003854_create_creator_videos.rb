class CreateCreatorVideos < ActiveRecord::Migration[8.1]
  def change
    create_table :creator_videos do |t|
      t.timestamps
    end
  end
end
