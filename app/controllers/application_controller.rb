class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :authenticate_user!

  layout :set_layout

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

  def set_layout
    return "application" unless user_signed_in?

    case current_user.role
    when "admin"    then "admin"
    when "agent"    then "agent"
    when "manager"  then "manager"
    when "customer" then "customer"
    else "application"
    end
  end

  def unauthorized!
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back(fallback_location: root_path)
  end

  # ── Post-login redirect ────────────────────────────────────────────────────

  def after_sign_in_path_for(resource)
    if resource.admin?
      admin_root_path
    elsif resource.agent?
      agent_root_path
    elsif resource.manager?
      manager_root_path
    else
      customer_root_path
    end
  end

end
