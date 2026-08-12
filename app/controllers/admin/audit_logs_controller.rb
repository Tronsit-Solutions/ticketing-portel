class Admin::AuditLogsController < ApplicationController
  before_action :require_admin!

  def index
    logs = AuditLog.includes(:actor).recent

    logs = logs.in_category(params[:category]) if params[:category].present? && AuditLog::CATEGORIES.include?(params[:category])
    logs = logs.with_action(params[:action_type]) if params[:action_type].present? && AuditLog::ACTIONS.include?(params[:action_type])
    logs = logs.by_actor(params[:actor_id]) if params[:actor_id].present?
    logs = logs.search(params[:search].strip) if params[:search].present?
    logs = logs.between_dates(params[:from], params[:to]) if params[:from].present? || params[:to].present?

    @stats = {
      total:   AuditLog.count,
      today:   AuditLog.where("created_at >= ?", Time.zone.now.beginning_of_day).count,
      logins:  AuditLog.with_action(AuditLog::LOGIN).count,
      failed:  AuditLog.with_action(AuditLog::LOGIN_FAILED).count
    }

    @actors = User.where(id: AuditLog.select(:actor_id)).order(:fullname)
    @logs   = logs.page(params[:page]).per(20)
  end

  def show
    @log = AuditLog.find(params[:id])
  end
end
