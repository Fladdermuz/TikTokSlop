class Admin::DashboardsController < Admin::BaseController
  def show
    @stats = {
      total_shops:       Shop.count,
      total_users:       User.count,
      total_invites:     Invite.cross_tenant.count,
      total_samples:     Sample.cross_tenant.count,
      spark_codes:       Sample.cross_tenant.where(status: "spark_code_received").count,
      ai_cost_30d_cents: AiUsageLog.cross_tenant.where("created_at >= ?", 30.days.ago).sum(:cost_cents),
      ai_calls_30d:      AiUsageLog.cross_tenant.where("created_at >= ?", 30.days.ago).count,
      queue_depth:       SolidQueue::Job.where(finished_at: nil).count
    }
    @recent_shops = Shop.order(created_at: :desc).limit(10)
    @recent_users = User.order(created_at: :desc).limit(10)
  end
end
