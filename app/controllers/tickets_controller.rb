class TicketsController < ApplicationController
  before_action :set_ticket,            only: [:show, :assign, :self_assign, :close]
  before_action :authorize_show!,        only: [:show]
  before_action :authorize_assign!,      only: [:assign]
  before_action :authorize_self_assign!, only: [:self_assign]
  before_action :authorize_close!,       only: [:close]

  def catalogue
    @catalogue = Ticket::CATALOGUE
  end

  def index
    @tickets = if current_user.customer?
      Ticket.where(customer: current_user).recent
    else
      Ticket.all.recent
    end.includes(:customer, :assignee, :location)

    @tickets = @tickets.where(status: params[:status])           if params[:status].present?
    @tickets = @tickets.where(ticket_type: params[:ticket_type]) if params[:ticket_type].present?
    @tickets = @tickets.where(assignee_id: nil)                  if params[:unassigned].present?
    @tickets = @tickets.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?
  end

  def show
    @ticket_messages    = @ticket.ticket_messages.recent
    @ticket_assignments = @ticket.ticket_assignments.recent.includes(:assigned_to, :assigned_from, :assigned_by)
    @ticket_files       = @ticket.ticket_files
  end

  def new
    @ticket      = Ticket.new(ticket_type: params[:ticket_type])
    @ticket_type = Ticket::CATALOGUE.find { |c| c[:type] == params[:ticket_type] }
    @customers   = User.customers.active.order(:fullname) if current_user.agent? || current_user.manager?
  end

  def create
    @ticket = Ticket.new(ticket_params)

    if current_user.agent? || current_user.manager?
      @ticket.customer    = User.find(params[:ticket][:customer_id])
      @ticket.created_by  = current_user
      # @ticket.assignee    = current_user
      # @ticket.assigned_by = current_user
      # @ticket.assigned_at = Time.current
      @ticket.status      = "in_progress"
    else
      @ticket.customer = current_user
    end

    if @ticket.save
      save_attachments(@ticket)
      redirect_to @ticket, notice: "Ticket submitted successfully."
    else
      @ticket_type = Ticket::CATALOGUE.find { |c| c[:type] == params[:ticket][:ticket_type] }
      @customers   = User.customers.active.order(:fullname) if current_user.agent? || current_user.manager?
      render :new, status: :unprocessable_entity
    end
  end

  def assign
    before_assignee = @ticket.assignee
    @ticket.update!(
      assignee_id: params[:assignee_id],
      assigned_by: current_user,
      assigned_at: Time.current,
      status:      "in_progress"
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

  def authorize_show!
    return if current_user.admin? || current_user.manager? || current_user.agent?
    unauthorized! unless @ticket.customer == current_user
  end

  def authorize_assign!
    unauthorized! unless current_user.admin? || current_user.manager?
  end

  def authorize_self_assign!
    unauthorized! unless current_user.admin? || current_user.agent?
  end

  def authorize_close!
    unless current_user.admin? ||
           @ticket.assignee == current_user ||
           @ticket.customer == current_user
      unauthorized!
    end
  end

  def ticket_params
    params.require(:ticket).permit(:ticket_type, :title, :location_id, metadata: {})
  end

  def save_attachments(ticket)
    return unless params[:ticket_attachments].present?
    image_exts = %w[jpg jpeg png gif webp]
    params[:ticket_attachments].each do |file|
      ext = File.extname(file.original_filename).delete(".").downcase
      if image_exts.include?(ext)
        ticket.ticket_files.create!(image: file)
      else
        ticket.ticket_files.create!(file: file)
      end
    end
  end
end
