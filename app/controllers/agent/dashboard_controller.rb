class Agent::DashboardController < ApplicationController
  before_action :require_admin_or_agent!
  layout "agent"
  
  def index
    @assigned_tickets   = current_user.assigned_tickets.count
    @unassigned_tickets = Ticket.unassigned.count
    @closed_tickets     = current_user.assigned_tickets.closed.count
    @my_tickets         = current_user.assigned_tickets.recent.includes(:customer).limit(10)
  end
end
