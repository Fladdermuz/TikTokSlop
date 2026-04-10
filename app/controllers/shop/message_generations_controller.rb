# AJAX endpoint for the "Generate from product" button in the campaign editor.
# Calls Messaging::Crafter.template_for and returns a Turbo partial with the
# generated template text + moderation result.
class Shop::MessageGenerationsController < Shop::BaseController
  def create
    campaign_id = params[:campaign_id]
    @campaign = if campaign_id.present?
      Current.shop.campaigns.find(campaign_id)
    else
      # For new campaigns that haven't been saved yet — build a transient one
      build_transient_campaign
    end

    if @campaign.product.nil?
      render plain: "Select a product first.", status: :unprocessable_entity
      return
    end

    @result = Messaging::Crafter.template_for(campaign: @campaign, shop: Current.shop)
    render partial: "result", locals: { result: @result }
  rescue Ai::Client::Error => e
    render plain: "AI generation failed: #{e.message}", status: :service_unavailable
  end

  private

  def build_transient_campaign
    product = Current.shop.products.find_by(id: params[:product_id])
    Campaign.new(
      name: params[:campaign_name].presence || "Draft",
      product: product,
      commission_rate: params[:commission_rate].presence&.to_f || 0.10,
      sample_offer: params[:sample_offer] == "true",
      shop: Current.shop
    )
  end
end
