class Shop::ProductsController < Shop::BaseController
  before_action :set_product, only: %i[show edit update]

  def index
    authorize!(:index, Product)
    @products = Current.shop.products.order(created_at: :desc)
  end

  def new
    authorize!(:create, Product)
    @product = Current.shop.products.new(currency: "USD", status: "active")
  end

  def create
    authorize!(:create, Product)
    @product = Current.shop.products.new(product_params)
    if @product.save
      redirect_to shop_products_path, notice: "Product added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    authorize!(:show, @product)
  end

  def edit
    authorize!(:update, @product)
  end

  def update
    authorize!(:update, @product)
    if @product.update(product_params)
      redirect_to shop_product_path(@product), notice: "Product updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_product
    @product = Current.shop.products.find(params[:id])
  end

  def product_params
    permitted = params.expect(product: %i[name external_id image_url price_dollars currency status])
    if permitted[:price_dollars].present?
      permitted[:price_cents] = (permitted.delete(:price_dollars).to_f * 100).to_i
    end
    permitted
  end
end
