class TicketsController < ApplicationController
  before_action :set_ticket,            only: [:show, :assign, :self_assign, :close, :cancel]
  before_action :authorize_show!,        only: [:show]
  before_action :authorize_assign!,      only: [:assign]
  before_action :authorize_self_assign!, only: [:self_assign]
  before_action :authorize_close!,       only: [:close]
  before_action :authorize_cancel!,      only: [:cancel]

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
      @locations = Location.ordered
      @sort      = %w[id title].include?(params[:sort]) ? params[:sort] : "id"
      @direction = params[:direction] == "asc" ? "asc" : "desc"
      @tickets   = Ticket.all.order(@sort => @direction).includes(:customer, :assignee, :location)
      @tickets = @tickets.where(status: params[:status])           if params[:status].present?
      @tickets = @tickets.where(ticket_type: params[:ticket_type])  if params[:ticket_type].present?
      @tickets = @tickets.where(assignee_id: nil)                  if params[:unassigned].present? || params[:assignment] == "unassigned"
      @tickets = @tickets.where(assignee_id: current_user.id)      if params[:assignment] == "self_assigned"
      @tickets = @tickets.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?
      @tickets = @tickets.where(location_id: params[:location_id]) if params[:location_id].present?
      if params[:search].present?
        search_term = params[:search].strip
        ticket_id   = search_term.delete_prefix("#")
        if ticket_id.match?(/\A\d+\z/)
          @tickets = @tickets.where(id: ticket_id)
        else
          term     = "%#{search_term}%"
          @tickets = @tickets.where("title ILIKE :term", term: term)
        end
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

    if @ticket.ticket_type == "hiring"
      if @ticket.valid?
        is_termination = @ticket.metadata["request_type"] == "Termination"
        session[:pending_ticket] = ticket_params.to_h.merge(
          "ticket_type" => is_termination ? "departure" : "hiring",
          "customer_id" => params.dig(:ticket, :customer_id)
        )
        if is_termination
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
      @ticket.auto_self_assign_for_agent!
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

  def cancel
    @ticket.update!(
      status:      "closed",
      resolved_by: current_user,
      resolved_at: Time.current
    )
    notify_staff_of_cancellation
    redirect_to @ticket, notice: "Ticket cancelled."
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
    @catalogue = Ticket::CATALOGUE
    scope      = Ticket.where(customer: current_user)

    @open_tickets_count   = scope.where.not(status: %w[closed cancelled]).count
    @closed_tickets_count = scope.where(status: %w[closed cancelled]).count
    @all_count            = @open_tickets_count + @closed_tickets_count
    @active_tab           = params[:tab] == "closed" ? "closed" : "opened"

    tab_scope       = @active_tab == "closed" ? scope.where(status: %w[closed cancelled]) : scope.where.not(status: %w[closed cancelled])
    @listed_tickets = tab_scope.recent.includes(:customer).page(params[:page]).per(10)
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

  def notify_staff_of_cancellation
    receivers = User.where(role: "manager").active.to_a
    receivers << @ticket.assignee if @ticket.assignee.present?
    receivers.uniq.reject { |user| user == current_user }.each do |staff|
      TicketNotification.create!(
        ticket:       @ticket,
        responded_by: current_user,
        receiver:     staff,
        details:      "Ticket ##{@ticket.id} was cancelled by #{current_user.fullname}: \"#{@ticket.title}\"",
        status:       "unread"
      )
    end
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
    return unless @ticket.status == "cancelled"

    redirect_back(fallback_location: root_path, alert: "Cancelled tickets cannot be grabbed.")
  end

  def authorize_close!
    unless current_user.admin? ||
           @ticket.assignee == current_user ||
           @ticket.customer == current_user
      unauthorized!
    end
  end

  def authorize_cancel!
    unauthorized! unless current_user.admin? || @ticket.customer == current_user
  end

  def ticket_params
    params.require(:ticket).permit(:ticket_type, :title, :location_id, metadata: [:mobile, :details, :issue, :request_type, :full_name, { idea_types: [] }, { work_types: [] }, { hr_types: [] }])
  end

  def save_attachments(ticket)
    return unless params[:ticket_attachments].present?
    ticket.attachments.attach(params[:ticket_attachments])
  end
end
