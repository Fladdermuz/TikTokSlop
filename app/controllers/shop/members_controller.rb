class Shop::MembersController < Shop::BaseController
  def index
    authorize!(:index, Membership)
    @memberships = Current.shop.memberships.includes(:user).order(:role, :created_at)
  end

  def new
    authorize!(:create, Membership)
    @membership = Membership.new(role: "member")
  end

  def create
    authorize!(:create, Membership)
    email = params[:email_address].to_s.strip.downcase
    role = params[:role].to_s

    user = User.find_by(email_address: email)
    unless user
      redirect_to new_shop_member_path, alert: "No account found for #{email}. They need to sign up first." and return
    end

    if Current.shop.memberships.exists?(user: user)
      redirect_to shop_members_path, alert: "#{email} is already a member of this shop." and return
    end

    Membership.create!(
      user: user,
      shop: Current.shop,
      role: role.in?(Membership::ROLES) ? role : "member",
      invited_at: Time.current,
      joined_at: Time.current
    )
    redirect_to shop_members_path, notice: "#{user.display_name} added as #{role}."
  end

  def destroy
    authorize!(:destroy, Membership)
    membership = Current.shop.memberships.find(params[:id])

    if membership.owner? && Current.shop.memberships.owners.count <= 1
      redirect_to shop_members_path, alert: "Can't remove the last owner. Transfer ownership first." and return
    end

    if membership.user == Current.user
      redirect_to shop_members_path, alert: "You can't remove yourself. Ask another admin." and return
    end

    membership.destroy
    redirect_to shop_members_path, notice: "#{membership.user.display_name} removed."
  end
end
