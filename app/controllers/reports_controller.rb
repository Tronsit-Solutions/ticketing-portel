require "csv"

class ReportsController < ApplicationController
  before_action :require_staff!
  layout ->(controller) do
    case controller.current_user.role
    when "admin" then "admin"
    when "agent" then "agent"
    else "manager"
    end
  end

  def index
    @report = params[:report] == "agents" ? "agents" : "tickets"

    if @report == "agents"
      @teams  = Team.ordered
      @agents = filtered_agents

      respond_to do |format|
        format.html { @agents = @agents.page(params[:page]).per(25) }
        format.csv  { send_data agents_csv(@agents), filename: "agents-report-#{Date.current}.csv" }
      end
    else
      @locations = Location.ordered
      @customers = User.customers.active.order(:fullname)
      @tickets   = filtered_tickets

      respond_to do |format|
        format.html { @tickets = @tickets.page(params[:page]).per(25) }
        format.csv  { send_data tickets_csv(@tickets), filename: "tickets-report-#{Date.current}.csv" }
      end
    end
  end

  private

  def filtered_agents
    agents = User.agents.includes(:team)
    agents = agents.where(team_id: params[:team_id]) if params[:team_id].present?
    agents = agents.where(is_active: params[:agent_status]) if params[:agent_status].in?(%w[true false])

    if params[:search].present?
      term   = "%#{params[:search].strip}%"
      agents = agents.where("fullname ILIKE :term OR email ILIKE :term", term: term)
    end

    if params[:joined_start_date].present?
      agents = agents.where("users.created_at >= ?", Date.parse(params[:joined_start_date]).beginning_of_day)
    end
    if params[:joined_end_date].present?
      agents = agents.where("users.created_at <= ?", Date.parse(params[:joined_end_date]).end_of_day)
    end

    agents.order(:fullname)
  rescue ArgumentError
    agents.order(:fullname)
  end

  def filtered_tickets
    tickets = Ticket.all.recent.includes(:customer, :location)
    tickets = tickets.where(status: params[:status])           if params[:status].present?
    tickets = tickets.where(location_id: params[:location_id]) if params[:location_id].present?
    tickets = tickets.where(customer_id: params[:customer_id]) if params[:customer_id].present?

    tickets = tickets.where(ticket_type: params[:ticket_type]) if params[:ticket_type].present?

    if params[:start_date].present?
      tickets = tickets.where("tickets.created_at >= ?", Date.parse(params[:start_date]).beginning_of_day)
    end
    if params[:end_date].present?
      tickets = tickets.where("tickets.created_at <= ?", Date.parse(params[:end_date]).end_of_day)
    end

    tickets
  rescue ArgumentError
    tickets
  end

  def tickets_csv(tickets)
    CSV.generate(headers: true) do |csv|
      csv << ["Ticket ID", "Title", "Description", "Status", "Created Date/Time", "Customer (email)", "Location", "Ticket Type"]
      tickets.find_each do |ticket|
        csv << [
          ticket.id,
          ticket.title,
          ticket.details,
          ticket.status.humanize,
          ticket.created_at.strftime("%b %d, %Y %I:%M %p"),
          ticket.customer&.email,
          ticket.location&.name,
          ticket.type_label
        ]
      end
    end
  end

  def agents_csv(agents)
    CSV.generate(headers: true) do |csv|
      csv << ["Agent", "Email", "Team", "Status", "Joining Date", "Open", "Closed", "Total"]
      agents.find_each do |agent|
        assigned = agent.assigned_tickets
        csv << [
          agent.fullname,
          agent.email,
          agent.team&.name,
          agent.is_active? ? "Active" : "Inactive",
          agent.created_at.strftime("%b %d, %Y"),
          assigned.open.count + assigned.in_progress.count,
          assigned.closed.count,
          assigned.count
        ]
      end
    end
  end
end
