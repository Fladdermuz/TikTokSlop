class Shop::CampaignsController < Shop::BaseController
  before_action :set_campaign, only: %i[show edit update destroy transition]

  def index
    authorize!(:index, Campaign)
    @campaigns = Current.shop.campaigns.includes(:product).order(created_at: :desc)
  end

  def show
    authorize!(:show, @campaign)
    @invite_counts = {
      total:     @campaign.invites.count,
      pending:   @campaign.pending_invite_count,
      sent:      @campaign.sent_invite_count,
      accepted:  @campaign.accepted_invite_count,
      failed:    @campaign.invites.where(status: "failed").count
    }
    @samples = @campaign.samples.includes(:invite).order(created_at: :desc).limit(10)
  end

  def new
    authorize!(:create, Campaign)
    @campaign = Current.shop.campaigns.new(status: "draft", commission_rate: 0.10, sample_offer: true)
    ensure_products_exist
  end

  def create
    authorize!(:create, Campaign)
    @campaign = Current.shop.campaigns.new(campaign_params)
    if @campaign.save
      redirect_to shop_campaign_path(@campaign), notice: "Campaign created as draft."
    else
      ensure_products_exist
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize!(:update, @campaign)
    if @campaign.ended?
      redirect_to shop_campaign_path(@campaign), alert: "Ended campaigns are read-only." and return
    end
    @editable_fields = @campaign.editable_fields
  end

  def update
    authorize!(:update, @campaign)
    if @campaign.ended?
      redirect_to shop_campaign_path(@campaign), alert: "Ended campaigns are read-only." and return
    end

    permitted = campaign_params.slice(*@campaign.editable_fields.map(&:to_sym))
    if @campaign.update(permitted)
      redirect_to shop_campaign_path(@campaign), notice: "Campaign updated."
    else
      @editable_fields = @campaign.editable_fields
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize!(:destroy, @campaign)
    if @campaign.invites.any?
      redirect_to shop_campaign_path(@campaign), alert: "Can't delete a campaign with invites. End it instead."
    else
      @campaign.destroy
      redirect_to shop_campaigns_path, notice: "Campaign deleted."
    end
  end

  # POST /shop/campaigns/:id/transition?to=active
  def transition
    authorize!(:update, @campaign)
    to_state = params[:to].to_s
    if @campaign.transition_to!(to_state)
      redirect_to shop_campaign_path(@campaign), notice: "Campaign #{to_state}."
    else
      redirect_to shop_campaign_path(@campaign), alert: @campaign.errors.full_messages.to_sentence
    end
  end

  private

  def set_campaign
    @campaign = Current.shop.campaigns.find(params[:id])
  end

  def campaign_params
    params.expect(campaign: %i[name product_id commission_rate sample_offer message_template follow_up_template personalize_per_creator notes status mode max_samples_per_creator sample_valid_days sample_min_follower_threshold ab_test_enabled commission_rate_b cohort_b_split_pct])
  end

  def ensure_products_exist
    return if Current.shop.products.active.any?
    flash.now[:alert] = "You need to add a product before creating a campaign. Go to Products → New."
  end
end
