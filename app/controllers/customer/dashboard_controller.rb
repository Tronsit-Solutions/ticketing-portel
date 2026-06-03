class Customer::DashboardController < ApplicationController
  def index
    @my_tickets    = Ticket.where(customer: current_user).recent.includes(:assignee)
    @open_tickets  = @my_tickets.open.count
    @closed_tickets = @my_tickets.closed.count
    @notifications = TicketNotification.for_user(current_user).unread
  end
end
