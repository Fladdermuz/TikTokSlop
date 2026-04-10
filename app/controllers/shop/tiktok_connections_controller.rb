class Shop::TiktokConnectionsController < Shop::BaseController
  before_action :load_token

  def show
    authorize!(:show, TiktokToken)
  end

  # Initiates the OAuth handshake. Generates a signed state token bound to the
  # current shop and user, then 302s the user to TikTok's authorize endpoint.
  def create
    authorize!(:create, TiktokToken)

    state = Tiktok::Resources::Authorization.build_state(
      shop_id: Current.shop.id,
      user_id: Current.user.id
    )
    redirect_to Tiktok::Resources::Authorization.authorize_url(state: state),
                allow_other_host: true
  end

  def destroy
    authorize!(:destroy, TiktokToken)

    if @token&.destroy
      redirect_to shop_tiktok_connection_path, notice: "TikTok Shop disconnected. Campaigns and history are preserved."
    else
      redirect_to shop_tiktok_connection_path, alert: "Nothing to disconnect."
    end
  end

  private

  def load_token
    @token = Current.shop.tiktok_token
  end
end
