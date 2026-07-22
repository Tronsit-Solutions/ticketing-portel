require "csv"

class ReportsController < ApplicationController
  before_action :require_admin_or_manager!
  layout ->(controller) { controller.current_user.admin? ? "admin" : "manager" }

  def index
    @locations = Location.ordered
    @customers = User.customers.active.order(:fullname)
    @tickets   = filtered_tickets

    respond_to do |format|
      format.html { @tickets = @tickets.page(params[:page]).per(25) }
      format.csv  { send_data tickets_csv(@tickets), filename: "tickets-report-#{Date.current}.csv" }
    end
  end

  private

  def filtered_tickets
    tickets = Ticket.all.recent.includes(:customer, :assignee, :location)
    tickets = tickets.where(status: params[:status])           if params[:status].present?
    tickets = tickets.where(location_id: params[:location_id]) if params[:location_id].present?
    tickets = tickets.where(customer_id: params[:customer_id]) if params[:customer_id].present?

    if params[:ticket_type] == "hiring"
      tickets = tickets.hiring
    elsif params[:ticket_type] == "departure"
      tickets = tickets.departure
    elsif params[:ticket_type].present?
      tickets = tickets.where(ticket_type: params[:ticket_type])
    end

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
      csv << ["Ticket ID", "Status", "Created Date/Time", "Customer (email)", "Assignee", "Location", "Ticket Type"]
      tickets.find_each do |ticket|
        csv << [
          ticket.id,
          ticket.status.humanize,
          ticket.created_at.strftime("%b %d, %Y %I:%M %p"),
          ticket.customer&.email,
          ticket.assignee&.fullname || "Unassigned",
          ticket.location&.name,
          ticket.type_label
        ]
      end
    end
  end
end
