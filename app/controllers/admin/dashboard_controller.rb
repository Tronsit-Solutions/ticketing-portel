class Admin::DashboardController < ApplicationController
  before_action :require_admin!

  def index
    @total_tickets   = Ticket.count
    @open_tickets    = Ticket.open.count
    @in_progress     = Ticket.in_progress.count
    @unassigned      = Ticket.unassigned.count
    @closed_tickets  = Ticket.closed.count
    @total_agents    = User.agents.active.count
    @total_customers = User.customers.active.count
    @tickets_today   = Ticket.where(created_at: Time.current.beginning_of_day..Time.current.end_of_day).count
    @tickets_by_type = Ticket.group(:ticket_type).count
    @top_agents      = User.agents.active.joins(:assigned_tickets).group("users.id").order("COUNT(tickets.id) DESC").limit(5).select("users.*, COUNT(tickets.id) AS ticket_count")
    @recent_tickets  = Ticket.recent.includes(:customer, :assignee).limit(8)
  end
end
