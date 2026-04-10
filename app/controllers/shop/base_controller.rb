class Shop::BaseController < ApplicationController
  before_action :require_shop_context!
end
