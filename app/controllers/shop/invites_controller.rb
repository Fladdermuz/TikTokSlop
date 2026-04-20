class Shop::InvitesController < Shop::BaseController
  def index
    authorize!(:index, Invite)
    @invites = Current.shop.invites.includes(:creator, :campaign).order(created_at: :desc)
    @invites = @invites.where(campaign_id: params[:campaign_id]) if params[:campaign_id].present?
    @invites = @invites.where(status: params[:status]) if params[:status].present?
    @invites = @invites.limit(100)
  end

  def show
    authorize!(:show, Invite)
    @invite = Current.shop.invites.includes(:creator, :campaign).find(params[:id])
    @moderation_check = ModerationCheck.cross_tenant.latest_for(@invite).first
    @failure_analysis = @invite.raw["failure_analysis"]
  end

  # POST /shop/invites/:id/retry_send — re-enqueue a failed invite
  def retry_send
    @invite = Current.shop.invites.find(params[:id])
    authorize!(:retry, @invite)

    unless @invite.failed?
      redirect_to shop_invite_path(@invite), alert: "Only failed invites can be retried." and return
    end

    @invite.update!(status: "pending", error_message: nil)
    Tiktok::SendInviteJob.perform_later(@invite.id)
    redirect_to shop_invite_path(@invite), notice: "Retry queued."
  end

  # POST /shop/invites/:id/generate_link — generate a shareable acceptance link
  # Uses Generate Target Collaboration Link endpoint (seller.affiliate_collaboration.write)
  def generate_link
    @invite = Current.shop.invites.find(params[:id])
    authorize!(:update, @invite)

    unless @invite.external_id.present?
      redirect_to shop_invite_path(@invite), alert: "Invite has no TikTok collaboration yet — send it first." and return
    end

    token = Current.shop.tiktok_token
    unless token
      redirect_to shop_invite_path(@invite), alert: "TikTok Shop not connected." and return
    end

    resource = Tiktok::Resources::AffiliateCollaboration.new(token: token.access_token, shop_cipher: token.shop_cipher)
    url = resource.generate_link(collaboration_id: @invite.external_id)

    @invite.update!(raw: @invite.raw.merge("share_link" => url, "share_link_generated_at" => Time.current.iso8601))
    redirect_to shop_invite_path(@invite), notice: "Invitation link generated: #{url}"
  rescue Tiktok::Error => e
    redirect_to shop_invite_path(@invite), alert: "TikTok error: #{e.message}"
  end

  # POST /shop/invites/:id/reinvite — cancel current collab and re-send at a new commission rate
  # Uses Remove Target Collaboration + Create Target Collaboration (seller.affiliate_collaboration.write)
  def reinvite
    @invite = Current.shop.invites.find(params[:id])
    authorize!(:update, @invite)

    new_rate = params[:commission_rate].to_f
    if new_rate <= 0 || new_rate > 1
      redirect_to shop_invite_path(@invite), alert: "Commission rate must be between 0 and 1 (e.g. 0.25 for 25%)." and return
    end

    Tiktok::ReinviteJob.perform_later(@invite.id, new_rate)
    redirect_to shop_invite_path(@invite), notice: "Reinvite queued at #{(new_rate * 100).round(1)}% commission."
  end
end
