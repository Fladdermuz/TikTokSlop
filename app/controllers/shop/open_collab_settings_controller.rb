# Shop-wide settings for Open Collaboration.
# Wraps the Edit Open Collaboration Settings endpoint (seller.affiliate_collaboration.write).
class Shop::OpenCollabSettingsController < Shop::BaseController
  def show
    authorize!(:manage, Current.shop)
    @shop = Current.shop
  end

  def update
    authorize!(:manage, Current.shop)
    @shop = Current.shop

    if @shop.update(settings_params)
      push_to_tiktok
      redirect_to shop_open_collab_settings_path, notice: "Open collaboration settings saved."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def settings_params
    params.expect(shop: %i[open_collab_auto_add open_collab_default_commission_rate])
  end

  def push_to_tiktok
    token = Current.shop.tiktok_token
    return unless token

    product_ids = Current.shop.products.active.where.not(external_id: nil).pluck(:external_id)
    attrs = { auto_add_new_products: Current.shop.open_collab_auto_add }
    attrs[:default_commission_rate] = Current.shop.open_collab_default_commission_rate if Current.shop.open_collab_default_commission_rate.present?
    attrs[:product_ids] = product_ids if product_ids.any?

    Tiktok::Resources::AffiliateCollaboration.new(token: token.access_token, shop_cipher: token.shop_cipher)
      .edit_settings(**attrs)
  rescue Tiktok::Error => e
    Rails.logger.warn("[open_collab_settings] TikTok push failed: #{e.message}")
    flash[:alert] = "Saved locally but TikTok push failed: #{e.message}"
  end
end
