class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :authenticate_user!

  private

  # ── Role guards ────────────────────────────────────────────────────────────

  def require_admin!
    unauthorized! unless current_user.admin?
  end

  def require_admin_or_manager!
    unauthorized! unless current_user.admin? || current_user.manager?
  end

  def require_admin_or_agent!
    unauthorized! unless current_user.admin? || current_user.agent?
  end

  def require_staff!
    unauthorized! unless current_user.admin? || current_user.manager? || current_user.agent?
  end

  def unauthorized!
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back(fallback_location: root_path)
  end

  # ── Post-login redirect ────────────────────────────────────────────────────

  def after_sign_in_path_for(resource)
    if resource.admin?
      admin_dashboard_path
    elsif resource.agent?
      agent_dashboard_path
    elsif resource.manager?
      manager_dashboard_path
    else
      customer_dashboard_path
    end
  end

end
