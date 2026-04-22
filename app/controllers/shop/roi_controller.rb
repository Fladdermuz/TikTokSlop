class Shop::RoiController < Shop::BaseController
  SAMPLE_COST_CENTS = 2500 # rough internal estimate, $25/sample

  # GET /shop/roi
  def show
    authorize!(:show, Roi)

    @roi_data = build_roi_rows
    @total_revenue_cents   = @roi_data.sum { |r| r[:gmv_cents] }
    @total_commission_cents = @roi_data.sum { |r| r[:commission_cents] }
    @total_orders = @roi_data.sum { |r| r[:orders] }
    @total_videos = @roi_data.sum { |r| r[:videos] }
    @top_creator  = @roi_data.max_by { |r| r[:gmv_cents] }
  end

  private

  # Pull real per-creator rollups from affiliate_orders + creator_videos,
  # joined with invites + samples for outreach context.
  def build_roi_rows
    shop = Current.shop

    order_agg = shop.affiliate_orders
      .where.not(creator_id: nil)
      .group(:creator_id)
      .select("creator_id,
               COUNT(*) AS order_count,
               COALESCE(SUM(gmv_cents), 0) AS gmv_cents_sum,
               COALESCE(SUM(commission_cents), 0) AS commission_cents_sum")
      .index_by(&:creator_id)

    video_agg = shop.creator_videos
      .where.not(creator_id: nil)
      .group(:creator_id)
      .select("creator_id,
               COUNT(*) AS video_count,
               COALESCE(SUM(views), 0) AS views_sum")
      .index_by(&:creator_id)

    # Union of creator ids seen anywhere — orders, videos, or invites.
    creator_ids = (order_agg.keys + video_agg.keys +
                   shop.invites.distinct.pluck(:creator_id)).compact.uniq
    return [] if creator_ids.empty?

    creators = Creator.where(id: creator_ids).index_by(&:id)

    invite_counts = shop.invites.where(creator_id: creator_ids).group(:creator_id).count
    sent_counts   = shop.invites.where(creator_id: creator_ids, status: "sent").group(:creator_id).count
    sample_counts = shop.samples.joins(:invite)
                         .where(invites: { creator_id: creator_ids })
                         .group("invites.creator_id").count

    creator_ids.map do |cid|
      creator = creators[cid]
      orders  = order_agg[cid]
      videos  = video_agg[cid]
      invites = invite_counts[cid].to_i
      sent    = sent_counts[cid].to_i
      samples = sample_counts[cid].to_i

      gmv_cents        = orders&.gmv_cents_sum.to_i
      commission_cents = orders&.commission_cents_sum.to_i
      sample_cost      = samples * SAMPLE_COST_CENTS
      net_cents        = gmv_cents - commission_cents - sample_cost
      roi_multiple     = sample_cost > 0 ? (gmv_cents.to_f / sample_cost).round(1) : nil

      {
        creator: creator,
        handle: creator&.handle,
        display_name: creator&.display_name || creator&.handle || "(unknown)",
        orders: orders&.order_count.to_i,
        gmv_cents: gmv_cents,
        commission_cents: commission_cents,
        videos: videos&.video_count.to_i,
        views:  videos&.views_sum.to_i,
        samples_sent: samples,
        acceptance_rate: invites > 0 ? (sent.to_f / invites * 100).round(1) : 0,
        sample_cost_cents: sample_cost,
        net_cents: net_cents,
        roi: roi_multiple
      }
    end.sort_by { |r| -r[:gmv_cents] }
  end
end
