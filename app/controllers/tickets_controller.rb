class TicketsController < ApplicationController
  before_action :set_ticket, only: [:show, :assign, :self_assign, :close]

  def index
    @tickets = if current_user.customer?
      Ticket.where(customer: current_user).recent
    else
      Ticket.all.recent
    end.includes(:customer, :assignee, :location)

    @tickets = @tickets.where(status: params[:status])              if params[:status].present?
    @tickets = @tickets.where(ticket_type: params[:ticket_type])    if params[:ticket_type].present?
    @tickets = @tickets.where(assignee_id: nil)                     if params[:unassigned].present?
    @tickets = @tickets.where(assignee_id: params[:assignee_id])    if params[:assignee_id].present?
  end

  def show
    @ticket_details     = @ticket.ticket_details.recent
    @ticket_assignments = @ticket.ticket_assignments.recent.includes(:assigned_to, :assigned_from, :assigned_by)
  end

  def new
    @ticket = Ticket.new
  end

  def create
    @ticket = Ticket.new(ticket_params)
    @ticket.customer = current_user
    if @ticket.save
      redirect_to @ticket, notice: "Ticket submitted successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def assign
    before_assignee = @ticket.assignee
    @ticket.update!(
      assignee_id:    params[:assignee_id],
      assigned_by:    current_user,
      assigned_at:    Time.current,
      status:         "in_progress"
    )
    TicketAssignment.create!(
      ticket:        @ticket,
      assigned_to:   User.find(params[:assignee_id]),
      assigned_from: before_assignee,
      assigned_by:   current_user,
      reason:        params[:reason]
    )
    redirect_to @ticket, notice: "Ticket assigned."
  end

  def self_assign
    @ticket.update!(
      assignee:    current_user,
      assigned_by: current_user,
      assigned_at: Time.current,
      status:      "in_progress"
    )
    TicketAssignment.create!(
      ticket:      @ticket,
      assigned_to: current_user,
      assigned_by: current_user,
      reason:      "Self-assigned"
    )
    redirect_to @ticket, notice: "Ticket self-assigned."
  end

  def close
    @ticket.update!(status: "closed", resolved_by: current_user, resolved_at: Time.current)
    redirect_to @ticket, notice: "Ticket closed."
  end

  private

  def set_ticket
    @ticket = Ticket.find(params[:id])
  end

  def ticket_params
    params.require(:ticket).permit(:ticket_type, :title, :location_id)
  end
end
