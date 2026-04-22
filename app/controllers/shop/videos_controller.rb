class Shop::VideosController < Shop::BaseController
  def index
    authorize!(:index, CreatorVideo)

    scope = Current.shop.creator_videos.includes(:creator, :product, :campaign).recent
    scope = scope.where(creator_id: params[:creator_id])   if params[:creator_id].present?
    scope = scope.where(campaign_id: params[:campaign_id]) if params[:campaign_id].present?
    @videos = scope.limit(100)

    # Leaderboard: group by creator, aggregate
    @leaderboard = Current.shop.creator_videos
      .where.not(creator_id: nil)
      .group(:creator_id)
      .select("creator_id,
               COUNT(*) AS video_count,
               SUM(views) AS total_views,
               SUM(likes + comments + shares) AS total_engagement,
               SUM(attributed_orders) AS total_orders,
               SUM(attributed_gmv_cents) AS total_gmv_cents")
      .order("total_gmv_cents DESC")
      .limit(25)

    creator_ids = @leaderboard.map(&:creator_id)
    @creators_by_id = Creator.where(id: creator_ids).index_by(&:id)
  end

  def show
    authorize!(:show, CreatorVideo)
    @video = Current.shop.creator_videos.includes(:creator, :product, :campaign, :invite).find(params[:id])
  end
end
