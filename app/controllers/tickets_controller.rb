class TicketsController < ApplicationController
  before_action :set_ticket,            only: [:show, :assign, :self_assign, :close]
  before_action :authorize_show!,        only: [:show]
  before_action :authorize_assign!,      only: [:assign]
  before_action :authorize_self_assign!, only: [:self_assign]
  before_action :authorize_close!,       only: [:close]

  def catalogue
    if current_user.customer?
      load_customer_home_data
      @active_panel = :catalogue
      render :customer_home
    else
      @catalogue = Ticket::CATALOGUE
    end
  end

  def index
    if current_user.customer?
      load_customer_home_data
      @active_panel = :my_tickets
      render :customer_home
    else
      @tickets = Ticket.all.recent.includes(:customer, :assignee, :location)
      @tickets = @tickets.where(status: params[:status])           if params[:status].present?
      @tickets = @tickets.where(ticket_type: params[:ticket_type]) if params[:ticket_type].present?
      @tickets = @tickets.where(assignee_id: nil)                  if params[:unassigned].present?
      @tickets = @tickets.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?
      if params[:search].present?
        term     = "%#{params[:search].strip}%"
        @tickets = @tickets.where("title ILIKE :term", term: term)
      end
      @tickets = @tickets.page(params[:page]).per(25)
    end
  end

  def show
    @ticket_messages    = @ticket.ticket_messages.recent
    @ticket_assignments = @ticket.ticket_assignments.recent.includes(:assigned_to, :assigned_from, :assigned_by)
    if current_user.customer?
      @my_tickets_count = Ticket.where(customer: current_user).count
      render :show_customer
    else
      render :show_agent
    end
  end

  def new
    @ticket           = Ticket.new(ticket_type: params[:ticket_type])
    @ticket_type      = Ticket::CATALOGUE.flat_map { |c| c[:children] || [c] }.find { |c| c[:type] == params[:ticket_type] }
    @customers        = User.customers.active.order(:fullname) unless current_user.customer?
    @my_tickets_count = Ticket.where(customer: current_user).count if current_user.customer?
  end

  def create
    @ticket = Ticket.new(ticket_params)
    apply_submitter!(@ticket)

    if @ticket.ticket_type == "hiring_departure"
      if @ticket.valid?
        session[:pending_ticket] = ticket_params.to_h.merge("customer_id" => params.dig(:ticket, :customer_id))
        if @ticket.metadata["request_type"] == "Termination"
          redirect_to new_pending_termination_detail_path
        else
          redirect_to new_pending_hiring_detail_path
        end
      else
        @ticket_type = Ticket::CATALOGUE.flat_map { |c| c[:children] || [c] }.find { |c| c[:type] == params[:ticket][:ticket_type] }
        @customers   = User.customers.active.order(:fullname) unless current_user.customer?
        flash.now[:alert] = @ticket.errors.full_messages.to_sentence
        render :new, status: :unprocessable_entity
      end
    elsif @ticket.save
      save_attachments(@ticket)
      notify_staff_of_new_ticket
      @ticket.notify_customer!(
        responded_by: current_user,
        details:      "#{current_user.fullname} submitted ticket ##{@ticket.id} on your behalf: \"#{@ticket.title}\""
      ) if @ticket.on_behalf?
      redirect_to @ticket, notice: "Ticket submitted successfully."
    else
      @ticket_type = Ticket::CATALOGUE.flat_map { |c| c[:children] || [c] }.find { |c| c[:type] == params[:ticket][:ticket_type] }
      @customers   = User.customers.active.order(:fullname) unless current_user.customer?
      flash.now[:alert] = @ticket.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def assign
    before_assignee  = @ticket.assignee
    new_assignee     = User.find(params[:assignee_id])

    @ticket.update!(
      assignee_id: new_assignee.id,
      assigned_by: current_user,
      assigned_at: Time.current,
      status:      "in_progress"
    )
    TicketAssignment.create!(
      ticket:        @ticket,
      assigned_to:   new_assignee,
      assigned_from: before_assignee,
      assigned_by:   current_user,
      reason:        params[:reason]
    )
    notify_assignee(new_assignee, assigned_by: current_user)
    @ticket.notify_customer!(
      responded_by: current_user,
      details:      "Your ticket ##{@ticket.id} has been assigned to #{new_assignee.fullname}: \"#{@ticket.title}\""
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
    notify_assignee(current_user, assigned_by: current_user)
    @ticket.notify_customer!(
      responded_by: current_user,
      details:      "Your ticket ##{@ticket.id} has been assigned to #{current_user.fullname}: \"#{@ticket.title}\""
    )
    redirect_to @ticket, notice: "Ticket self-assigned."
  end

  def close
    @ticket.update!(
      status:      "closed",
      resolved_by: current_user,
      resolved_at: Time.current,
      resolution:  params.dig(:resolution, :how_resolved).presence
    )
    @ticket.notify_customer!(
      responded_by: current_user,
      details:      "Your ticket ##{@ticket.id} has been closed: \"#{@ticket.title}\""
    )
    redirect_to @ticket, notice: "Ticket closed."
  end

  private

  def apply_submitter!(ticket)
    if current_user.agent? || current_user.manager?
      ticket.customer   = User.find(params[:ticket][:customer_id])
      ticket.created_by = current_user
      ticket.status     = "open"
    else
      ticket.customer = current_user
    end
  end

  def load_customer_home_data
    @catalogue      = Ticket::CATALOGUE
    all             = Ticket.where(customer: current_user).recent.includes(:customer)
    @open_tickets   = all.reject { |t| %w[closed cancelled].include?(t.status) }
    @closed_tickets = all.select { |t| %w[closed cancelled].include?(t.status) }
    @all_count      = all.count
    @active_tab     = params[:tab] == "closed" ? "closed" : "opened"
    @listed_tickets = @active_tab == "closed" ? @closed_tickets : @open_tickets
  end

  def set_ticket
    @ticket = Ticket.includes(
      :customer, :assignee, :assigned_by, :resolved_by, :created_by, :location,
      :hiring_detail, :termination_detail).find(params[:id])
  end

  def notify_staff_of_new_ticket
    User.where(role: %w[agent manager]).active.find_each do |staff|
      TicketNotification.create!(
        ticket:       @ticket,
        responded_by: current_user,
        receiver:     staff,
        details:      "New ticket ##{@ticket.id} submitted by #{current_user.fullname}: \"#{@ticket.title}\"",
        status:       "unread"
      )
    end
  end

  def notify_assignee(assignee, assigned_by:)
    TicketNotification.create!(
      ticket:       @ticket,
      responded_by: assigned_by,
      receiver:     assignee,
      details:      "You have been assigned ticket ##{@ticket.id}: \"#{@ticket.title}\"",
      status:       "unread"
    )
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
    params.require(:ticket).permit(:ticket_type, :title, :location_id, metadata: [:mobile, :details, :issue, :request_type, :full_name, { idea_types: [] }, { work_types: [] }, { hr_types: [] }])
  end

  def save_attachments(ticket)
    return unless params[:ticket_attachments].present?
    ticket.attachments.attach(params[:ticket_attachments])
  end
end
