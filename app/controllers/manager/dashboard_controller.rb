class Manager::DashboardController < ApplicationController
  layout "manager"
  before_action :require_admin_or_manager!

  def index
    @total_tickets   = Ticket.where(location_id: nil).or(Ticket.where(status: "open")).count
    @open_tickets    = Ticket.open.count
    @closed_tickets  = Ticket.closed.count
    @agents          = User.where(role: "agent", team_id: current_user.team_id)
                           .includes(:assigned_tickets)
  end
end
