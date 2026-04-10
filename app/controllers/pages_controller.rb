# Public static pages — no authentication required.
class PagesController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :resolve_current_shop

  def privacy; end
  def terms; end
end
