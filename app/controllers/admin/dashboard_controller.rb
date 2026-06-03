class Admin::DashboardController < ApplicationController
  before_action :require_admin!

  def index
    @total_tickets  = Ticket.count
    @open_tickets   = Ticket.open.count
    @in_progress    = Ticket.in_progress.count
    @unassigned     = Ticket.unassigned.count
    @recent_tickets = Ticket.recent.includes(:customer, :assignee).limit(10)
  end
end
