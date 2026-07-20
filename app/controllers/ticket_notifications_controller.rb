class TicketNotificationsController < ApplicationController
  def index
    @notifications = TicketNotification.for_user(current_user).recent.includes(:ticket, :responded_by).page(params[:page]).per(25)
  end

  def mark_read
    notification = TicketNotification.for_user(current_user).find(params[:id])
    notification.update!(status: "read")
    redirect_to ticket_path(notification.ticket)
  end

  def mark_all_read
    TicketNotification.for_user(current_user).unread.update_all(status: "read")
    redirect_to ticket_notifications_path, notice: "All notifications marked as read."
  end
end
