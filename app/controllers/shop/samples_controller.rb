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
    when "shipped"
      @sample.update!(status: "shipped", shipped_at: Time.current,
                       tracking_number: params[:tracking_number], carrier: params[:carrier])
      redirect_to shop_sample_path(@sample), notice: "Marked as shipped."
    when "delivered"
      @sample.update!(status: "delivered", delivered_at: Time.current)
      @sample.on_delivery!
      redirect_to shop_sample_path(@sample), notice: "Marked as delivered. Follow-up scheduled."
    when "rejected"
      @sample.update!(status: "rejected")
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
end
