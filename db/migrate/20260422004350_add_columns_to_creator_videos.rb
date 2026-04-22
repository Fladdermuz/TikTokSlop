class AddColumnsToCreatorVideos < ActiveRecord::Migration[8.1]
  def change
    add_reference :creator_videos, :shop,     null: false, foreign_key: true
    add_reference :creator_videos, :creator,  null: true,  foreign_key: true
    add_reference :creator_videos, :product,  null: true,  foreign_key: true
    add_reference :creator_videos, :campaign, null: true,  foreign_key: true
    add_reference :creator_videos, :invite,   null: true,  foreign_key: true

    add_column :creator_videos, :external_id,   :string
    add_column :creator_videos, :title,         :string
    add_column :creator_videos, :thumbnail_url, :string
    add_column :creator_videos, :video_url,     :string
    add_column :creator_videos, :posted_at,     :datetime

    add_column :creator_videos, :views,                :bigint,  default: 0, null: false
    add_column :creator_videos, :likes,                :bigint,  default: 0, null: false
    add_column :creator_videos, :comments,             :bigint,  default: 0, null: false
    add_column :creator_videos, :shares,               :bigint,  default: 0, null: false
    add_column :creator_videos, :attributed_orders,    :integer, default: 0, null: false
    add_column :creator_videos, :attributed_gmv_cents, :bigint,  default: 0, null: false
    add_column :creator_videos, :currency,             :string,  default: "USD", null: false

    add_column :creator_videos, :raw, :jsonb, default: {}, null: false

    add_index :creator_videos, :external_id, unique: true, where: "external_id IS NOT NULL"
    add_index :creator_videos, :posted_at
    add_index :creator_videos, [ :shop_id, :posted_at ]
  end
end
