require "csv"

class Shop::CreatorsController < Shop::BaseController
  def index
    authorize!(:index, Creator)
    @filters = Tiktok::CreatorSearch::Filters.from_params(params)
    @search = Tiktok::CreatorSearch.new(shop: Current.shop, filters: @filters)
    @creators = @search.call
    @total_count = @search.total_count
    @invited_creator_ids = invited_creator_ids_for(@creators)
  end

  def show
    authorize!(:show, Creator)
    @creator = Creator.find(params[:id])
    @invites = Current.shop.invites.where(creator_id: @creator.id).includes(:campaign).order(created_at: :desc)
    @samples = Current.shop.samples.joins(:invite).where(invites: { creator_id: @creator.id }).includes(:invite)
  end

  def export
    authorize!(:export, Creator)
    creator_ids = Array(params[:creator_ids]).reject(&:blank?).map(&:to_i)
    creators = Creator.where(id: creator_ids).order(:handle)

    csv = CSV.generate do |out|
      out << %w[handle display_name follower_count gmv_dollars gmv_tier engagement_rate country categories external_id]
      creators.each do |c|
        out << [
          c.handle,
          c.display_name,
          c.follower_count,
          c.gmv_dollars,
          c.gmv_tier,
          c.engagement_rate,
          c.country,
          Array(c.categories).join("|"),
          c.external_id
        ]
      end
    end

    send_data csv,
      filename: "tikedon-creators-#{Date.current.iso8601}-#{Current.shop.slug}.csv",
      type: "text/csv",
      disposition: "attachment"
  end

  private

  # Pre-computes which of the displayed creators have ever been invited from
  # this shop, so the table can show an "invited" badge in one query.
  def invited_creator_ids_for(creators)
    Current.shop.invites.where(creator_id: creators.map(&:id)).distinct.pluck(:creator_id).to_set
  end
end
