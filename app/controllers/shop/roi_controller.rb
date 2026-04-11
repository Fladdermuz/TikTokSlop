class Shop::RoiController < Shop::BaseController
  # GET /shop/roi
  def show
    authorize!(:show, Roi)

    # Fake ROI data for now — will be replaced with real affiliate order API data.
    # Each entry represents a creator's aggregate performance for this shop.
    @roi_data = build_fake_roi_data
    @total_revenue = @roi_data.sum { |r| r[:revenue] }
    @total_orders = @roi_data.sum { |r| r[:orders] }
    @top_creator = @roi_data.max_by { |r| r[:revenue] }
  end

  private

  def build_fake_roi_data
    creators = Creator.joins(:invites)
                      .where(invites: { shop_id: Current.shop.id })
                      .distinct
                      .limit(20)

    return seed_placeholder_data if creators.empty?

    creators.map do |creator|
      invite_count = Current.shop.invites.where(creator_id: creator.id).count
      sent_count = Current.shop.invites.where(creator_id: creator.id, status: "sent").count
      sample_count = Current.shop.samples.joins(:invite).where(invites: { creator_id: creator.id }).count

      # Generate deterministic-ish fake numbers from creator ID
      seed = creator.id * 7 + 13
      orders = (seed % 40) + 1
      revenue = orders * ((seed % 80) + 15) * 100 # cents → dollars range $15-$95 per order
      sample_cost = sample_count * 2500 # $25 per sample estimate

      {
        creator: creator,
        handle: creator.handle,
        display_name: creator.display_name || creator.handle,
        orders: orders,
        revenue: revenue,
        samples_sent: sample_count,
        acceptance_rate: sent_count > 0 ? (sent_count.to_f / [invite_count, 1].max * 100).round(1) : 0,
        sample_cost: sample_cost,
        roi: sample_cost > 0 ? (revenue.to_f / sample_cost).round(1) : nil
      }
    end.sort_by { |r| -r[:revenue] }
  end

  def seed_placeholder_data
    # If no creators have been invited yet, show placeholder data
    [
      { handle: "sample_creator", display_name: "Sample Creator", orders: 12, revenue: 48000, samples_sent: 2, acceptance_rate: 85.0, sample_cost: 5000, roi: 9.6, creator: nil },
      { handle: "demo_influencer", display_name: "Demo Influencer", orders: 8, revenue: 32000, samples_sent: 1, acceptance_rate: 100.0, sample_cost: 2500, roi: 12.8, creator: nil },
      { handle: "test_creator", display_name: "Test Creator", orders: 3, revenue: 9500, samples_sent: 1, acceptance_rate: 50.0, sample_cost: 2500, roi: 3.8, creator: nil }
    ]
  end
end
