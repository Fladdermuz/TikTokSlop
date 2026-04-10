class Tiktok::OauthController < ApplicationController
  # The OAuth callback handler. TikTok redirects the user here after they
  # authorize Tikedon against their Shop seller account.
  #
  # Flow:
  #   1. Verify the signed `state` token (CSRF + shop binding)
  #   2. Confirm the logged-in user is the same one who initiated OAuth, and is
  #      still a member of the target shop
  #   3. Exchange the `code` for an access/refresh token pair
  #   4. Persist (or update) the TiktokToken for the shop, encrypting tokens at rest
  #   5. Optionally fetch the shop_cipher (needed for shop-scoped API calls)
  #   6. Set the current shop and redirect to its dashboard
  #
  # Errors at any step redirect back to the connection page with a flash.
  def callback
    state_payload = verify_state!(params[:state])
    return if performed?

    code = params[:code].to_s
    if code.blank?
      redirect_to_failure("Authorization code missing from TikTok callback.")
      return
    end

    shop = Shop.find_by(id: state_payload[:shop_id])
    if shop.nil? || !Current.user.member_of?(shop)
      redirect_to_failure("That shop is no longer available to you.")
      return
    end

    if Current.user.id != state_payload[:user_id]
      redirect_to_failure("OAuth state user mismatch. Try connecting again.")
      return
    end

    pair = exchange_code(code)
    return if performed?

    persist_token(shop, pair)

    session[:current_shop_id] = shop.id
    redirect_to shop_dashboard_path, notice: "TikTok Shop connected for #{shop.name}."
  end

  private

  def verify_state!(token)
    Tiktok::Resources::Authorization.verify_state(token).symbolize_keys
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageEncryptor::InvalidMessage
    redirect_to_failure("OAuth state was invalid or expired. Try connecting again.")
    nil
  end

  def exchange_code(code)
    Tiktok::Resources::Authorization.exchange_code(code)
  rescue Tiktok::AuthError => e
    redirect_to_failure("TikTok rejected the authorization: #{e.message}")
    nil
  rescue Tiktok::Error => e
    Rails.logger.error("[tiktok oauth] #{e.class.name}: #{e.message} request_id=#{e.request_id}")
    redirect_to_failure("Failed to exchange auth code with TikTok. Try again.")
    nil
  end

  def persist_token(shop, pair)
    token = TiktokToken.cross_tenant.find_or_initialize_by(shop_id: shop.id)
    token.assign_attributes(
      external_shop_id:   pair.open_id || pair.raw["seller_id"] || "unknown",
      seller_name:        pair.seller_name,
      access_token:       pair.access_token,
      refresh_token:      pair.refresh_token,
      access_expires_at:  pair.access_expires_at,
      refresh_expires_at: pair.refresh_expires_at
    )
    token.save!

    # Best-effort: capture shop_cipher and shop_name from the shop list endpoint.
    # If this fails, the connection still works for token-only operations and
    # the user can retry by re-connecting.
    begin
      shop_info = Tiktok::Resources::Shop.first_for(token: token)
      if shop_info
        token.update!(
          shop_cipher: shop_info["cipher"],
          shop_name:   shop_info["shop_name"] || shop_info["name"],
          external_shop_id: shop_info["id"] || token.external_shop_id
        )
      end
    rescue Tiktok::Error => e
      Rails.logger.warn("[tiktok oauth] failed to fetch shop info: #{e.message}")
    end
  end

  def redirect_to_failure(message)
    if Current.shop.present?
      redirect_to shop_tiktok_connection_path, alert: message
    else
      redirect_to root_path, alert: message
    end
  end
end
