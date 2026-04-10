class Admin::BaseController < ApplicationController
  before_action :require_platform_admin!

  private

  def require_platform_admin!
    unless Current.user&.platform_admin?
      redirect_to root_path, alert: "Platform admin access required."
    end
  end
end
