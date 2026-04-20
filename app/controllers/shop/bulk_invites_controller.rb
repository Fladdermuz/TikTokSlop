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

  # GET /shop/bulk_invites/import — show the CSV upload form
  def import
    authorize!(:create, Invite)
    @campaigns = Current.shop.campaigns.where(status: "active").includes(:product).order(:name)
  end

  # POST /shop/bulk_invites/import_csv — parse uploaded CSV and queue invites
  # CSV format: one handle per line (optional header "handle"). Unknown handles
  # are reported back and skipped; known handles are queued via BulkInviteJob.
  def import_csv
    authorize!(:create, Invite)
    campaign = Current.shop.campaigns.find(params[:campaign_id])

    unless campaign.active?
      redirect_to import_shop_bulk_invites_path, alert: "Campaign must be active." and return
    end

    file = params[:csv_file]
    unless file.respond_to?(:read)
      redirect_to import_shop_bulk_invites_path, alert: "No CSV file uploaded." and return
    end

    handles = parse_handles(file.read)
    if handles.empty?
      redirect_to import_shop_bulk_invites_path, alert: "No creator handles found in the file." and return
    end

    creators = Creator.where(handle: handles).to_a
    found_handles = creators.map(&:handle)
    missing = handles - found_handles

    if creators.empty?
      redirect_to import_shop_bulk_invites_path,
        alert: "None of the #{handles.size} handle(s) matched known creators. Missing: #{missing.take(10).join(', ')}"
      return
    end

    Tiktok::BulkInviteJob.perform_later(Current.shop.id, campaign.id, creators.map(&:id))

    message = "Queued #{creators.size} invites for #{campaign.name}."
    message += " Skipped #{missing.size} unknown handle(s): #{missing.take(5).join(', ')}#{'…' if missing.size > 5}" if missing.any?
    redirect_to shop_campaign_path(campaign), notice: message
  end

  private

  def parse_handles(csv_text)
    require "csv"
    handles = []
    CSV.parse(csv_text) do |row|
      next if row.empty?
      handle = row.first.to_s.strip.sub(/^@/, "")
      next if handle.blank? || handle.downcase == "handle" # skip header
      handles << handle
    end
    handles.uniq
  end
end
