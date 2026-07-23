class TicketNotificationsController < ApplicationController
  def index
    @notifications = TicketNotification.for_user(current_user).recent.includes(:ticket, :responded_by).page(params[:page]).per(10)
  end

  def mark_read
    notification = TicketNotification.for_user(current_user).find(params[:id])
    notification.update!(status: "read")

    if notification.ticket.present?
      redirect_to ticket_path(notification.ticket)
    elsif notification.responded_by.present?
      redirect_to user_show_path_for(notification.responded_by)
    else
      redirect_to ticket_notifications_path
    end
  end

  def mark_all_read
    TicketNotification.for_user(current_user).unread.update_all(status: "read")
    redirect_to ticket_notifications_path, notice: "All notifications marked as read."
  end

  def unread_count
    render json: { count: TicketNotification.for_user(current_user).unread.count }
  end

  private

  def user_show_path_for(user)
    current_user.manager? ? manager_user_path(user) : user_path(user)
  end
end
