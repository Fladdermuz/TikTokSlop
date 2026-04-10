class Shop::ProductKnowledgesController < Shop::BaseController
  before_action :set_product
  before_action :set_knowledge

  def show
    authorize!(:show, @product)
  end

  def edit
    authorize!(:update, @product)
  end

  def update
    authorize!(:update, @product)
    if @knowledge.update(knowledge_params)
      redirect_to shop_product_knowledge_path(@product), notice: "Product knowledge updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_product
    @product = Current.shop.products.find(params[:product_id])
  end

  def set_knowledge
    @knowledge = @product.knowledge || @product.build_knowledge
  end

  def knowledge_params
    params.expect(product_knowledge: %i[
      short_description long_description ingredients benefits
      target_audience use_cases usp brand_name brand_voice
      size_or_serving warnings
    ])
  end
end
