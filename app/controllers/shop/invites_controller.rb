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
end
