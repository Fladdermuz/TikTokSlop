# Handles the "Invite to campaign" flow from the creator search page.
# POST /shop/bulk_invites with creator_ids[] + campaign_id.
class Shop::BulkInvitesController < Shop::BaseController
  def new
    authorize!(:create, Invite)
    @creator_ids = Array(params[:creator_ids]).reject(&:blank?).map(&:to_i)
    @creators = Creator.where(id: @creator_ids).order(:handle)
    @campaigns = Current.shop.campaigns.where(status: "active").includes(:product).order(:name)
  end

  def create
    authorize!(:create, Invite)
    campaign = Current.shop.campaigns.find(params[:campaign_id])
    creator_ids = Array(params[:creator_ids]).reject(&:blank?).map(&:to_i)

    unless campaign.active?
      redirect_to shop_creators_path, alert: "Campaign must be active to send invites." and return
    end

    if creator_ids.empty?
      redirect_to shop_creators_path, alert: "No creators selected." and return
    end

    Tiktok::BulkInviteJob.perform_later(Current.shop.id, campaign.id, creator_ids)

    redirect_to shop_campaign_path(campaign),
      notice: "Queued #{creator_ids.size} invites for #{campaign.name}. They'll be sent over the next few minutes."
  end
end
