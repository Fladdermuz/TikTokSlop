class ApplicationController < ActionController::Base
  include Authentication
  include ShopContext
  include Authorization

  allow_browser versions: :modern

  stale_when_importmap_changes
end
