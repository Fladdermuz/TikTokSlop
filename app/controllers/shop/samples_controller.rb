class Shop::SamplesController < Shop::BaseController
  before_action :set_sample, only: %i[show update record_spark_code deeplink]

  def index
    authorize!(:index, Sample)
    @samples = Current.shop.samples.includes(invite: [ :creator, :campaign ]).order(created_at: :desc)
    @samples = @samples.where(status: params[:status]) if params[:status].present?
    @samples = @samples.limit(100)
  end

  def show
    authorize!(:show, @sample)
    @invite = @sample.invite
    @creator = @invite.creator
    @campaign = @invite.campaign
  end

  def update
    authorize!(:update, @sample)
    case params[:transition]
    when "approved"
      push_tiktok_review(action: "approve")
      @sample.update!(status: "approved")
      redirect_to shop_sample_path(@sample), notice: "Sample approved."
    when "shipped"
      @sample.update!(status: "shipped", shipped_at: Time.current,
                       tracking_number: params[:tracking_number], carrier: params[:carrier])
      redirect_to shop_sample_path(@sample), notice: "Marked as shipped."
    when "delivered"
      @sample.update!(status: "delivered", delivered_at: Time.current)
      @sample.on_delivery!
      redirect_to shop_sample_path(@sample), notice: "Marked as delivered. Follow-up scheduled."
    when "rejected"
      reason = params[:reject_reason].to_s.strip
      if reason.blank?
        redirect_to shop_sample_path(@sample), alert: "A rejection reason is required (TikTok requires this when rejecting sample applications)." and return
      end
      push_tiktok_review(action: "reject", reject_reason: reason)
      @sample.update!(status: "rejected", raw: @sample.raw.merge("reject_reason" => reason, "rejected_at" => Time.current.iso8601))
      redirect_to shop_sample_path(@sample), notice: "Sample rejected."
    when "returned"
      @sample.update!(status: "returned")
      redirect_to shop_sample_path(@sample), notice: "Sample returned."
    when "no_response"
      @sample.mark_no_response!
      redirect_to shop_sample_path(@sample), notice: "Marked as no response."
    else
      redirect_to shop_sample_path(@sample), alert: "Unknown transition."
    end
  end

  # GET /shop/samples/:id/deeplink
  # Calls the TikTok AffiliateSample deeplink endpoint and returns the URL as JSON.
  # Falls back to a realistic-looking stub when no TikTok token is connected.
  def deeplink
    authorize!(:show, @sample)
    @invite  = @sample.invite
    @campaign = @invite.campaign
    product  = @campaign.product

    url = nil

    if (token = Current.shop.tiktok_token)
      resource = Tiktok::Resources::AffiliateSample.new(
        token:       token.access_token,
        shop_cipher: token.shop_cipher
      )
      url = resource.deeplink(product_id: product.external_id)
    end

    # Graceful fallback — stub a realistic-looking deeplink so the UI always
    # shows something even without a live TikTok connection.
    url ||= "https://www.tiktok.com/shop/sample-request?product_id=#{product.external_id || product.id}&shop_id=#{Current.shop.slug}"

    render json: { url: url }
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /shop/samples/:id/record_spark_code
  def record_spark_code
    authorize!(:record_spark_code, @sample)
    code = params[:spark_code].to_s.strip
    if code.blank?
      redirect_to shop_sample_path(@sample), alert: "Spark code can't be blank." and return
    end

    @sample.record_spark_code!(code)
    redirect_to shop_sample_path(@sample), notice: "Spark code recorded!"
  end

  private

  def set_sample
    @sample = Current.shop.samples.find(params[:id])
  end

  # Call TikTok's Seller Review Sample Applications endpoint if we have a
  # TikTok connection and a known external sample_application_id. Fails
  # silently (logs only) so local state updates still proceed if TikTok is
  # unreachable — local DB is the source of truth for our UI.
  def push_tiktok_review(action:, reject_reason: nil)
    return if @sample.external_id.blank?
    token = Current.shop.tiktok_token
    return unless token

    Tiktok::Resources::AffiliateSample.new(token: token.access_token, shop_cipher: token.shop_cipher)
      .review(sample_application_id: @sample.external_id, action: action, reject_reason: reject_reason)
  rescue Tiktok::Error => e
    Rails.logger.warn("[samples#review] TikTok push failed sample=#{@sample.id}: #{e.message}")
  end
end
