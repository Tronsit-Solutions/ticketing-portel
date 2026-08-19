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

  REPORTS = %w[tickets agents agent_detail].freeze
  TICKETS_CSV_HEADERS = ["Ticket ID", "Title", "Description", "Status", "Created Date/Time", "Customer (email)", "Location", "Ticket Type"].freeze

  def index
    @report = REPORTS.include?(params[:report]) ? params[:report] : "tickets"

    case @report
    when "agents"        then index_agents
    when "agent_detail"  then index_agent_detail
    else                      index_tickets
    end
  end

  private

  def index_tickets
    @locations = Location.ordered
    @customers = User.customers.active.order(:fullname)
    @tickets   = filtered_tickets

    respond_to do |format|
      format.html { @tickets = @tickets.page(params[:page]).per(25) }
      format.csv  { send_data tickets_csv(@tickets), filename: "tickets-report-#{Date.current}.csv" }
    end
  end

  def index_agents
    @teams  = Team.ordered
    @agents = filtered_agents

    respond_to do |format|
      format.html { @agents = @agents.page(params[:page]).per(25) }
      format.csv  { send_data agents_csv(@agents), filename: "agents-report-#{Date.current}.csv" }
    end
  end

  def index_agent_detail
    @agent = User.agents.find(params[:agent_id])
    @locations = Location.ordered
    @customers = User.customers.active.order(:fullname)
    @tickets   = filtered_tickets.where(assignee_id: @agent.id)

    respond_to do |format|
      format.html { @tickets = @tickets.page(params[:page]).per(25) }
      format.csv do
        filename = "agent-report-#{@agent.fullname.parameterize}-#{Date.current}.csv"
        send_data agent_detail_csv(@agent, @tickets), filename: filename
      end
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to url_for(only_path: true, format: nil, report: "agents"), alert: "Agent not found."
  end

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

  def ticket_csv_row(ticket)
    [
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

  def tickets_csv(tickets)
    CSV.generate(headers: true) do |csv|
      csv << TICKETS_CSV_HEADERS
      tickets.find_each { |ticket| csv << ticket_csv_row(ticket) }
    end
  end

  def agent_csv_row(agent)
    stats = agent.ticket_stats
    [
      agent.fullname,
      agent.email,
      agent.team&.name,
      agent.is_active? ? "Active" : "Inactive",
      agent.created_at.strftime("%b %d, %Y"),
      stats[:open],
      stats[:closed],
      stats[:total]
    ]
  end

  def agents_csv(agents)
    CSV.generate(headers: true) do |csv|
      csv << ["Agent", "Email", "Team", "Status", "Joining Date", "Open", "Closed", "Total"]
      agents.find_each { |agent| csv << agent_csv_row(agent) }
    end
  end

  def agent_detail_csv(agent, tickets)
    CSV.generate(headers: true) do |csv|
      csv << ["Agent Details"]
      csv << ["Agent", "Email", "Team", "Status", "Joining Date", "Open", "Closed", "Total"]
      csv << agent_csv_row(agent)
      csv << []
      csv << ["Tickets"]
      csv << TICKETS_CSV_HEADERS
      tickets.find_each { |ticket| csv << ticket_csv_row(ticket) }
    end
  end
end
