class TerminationDetailsController < ApplicationController
  before_action :set_ticket, only: [:new, :create]
  before_action :set_my_tickets_count, only: [:new, :create, :new_pending, :create_pending]

  def new
    if @ticket.termination_detail.present?
      redirect_to @ticket, notice: "Termination details already submitted."
      return
    end
    @termination_detail = @ticket.build_termination_detail
  end

  def create
    if @ticket.termination_detail.present?
      redirect_to @ticket, notice: "Termination details already submitted."
      return
    end

    @termination_detail = @ticket.build_termination_detail(termination_detail_params)

    if @termination_detail.save
      redirect_to @ticket, notice: "Termination details submitted successfully."
    else
      flash.now[:alert] = @termination_detail.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  # Step 2 of the new-ticket flow: the ticket itself has not been persisted
  # yet (see TicketsController#create) — it lives in the session until this
  # form is submitted, so both the ticket and its termination detail are
  # created together, or neither is.
  def new_pending
    @ticket = build_pending_ticket
    return redirect_to new_ticket_path, alert: "Your ticket details expired. Please start again." unless @ticket

    @termination_detail = @ticket.build_termination_detail
    render :new
  end

  def create_pending
    @ticket = build_pending_ticket
    return redirect_to new_ticket_path, alert: "Your ticket details expired. Please start again." unless @ticket

    @termination_detail = @ticket.build_termination_detail(termination_detail_params)

    ActiveRecord::Base.transaction do
      @ticket.save!
      @termination_detail.save!
    end
    session.delete(:pending_ticket)
    @ticket.auto_self_assign_for_agent!
    notify_staff_of_new_ticket(@ticket)
    @ticket.notify_customer!(
      responded_by: current_user,
      details:      "#{current_user.fullname} submitted ticket ##{@ticket.id} on your behalf: \"#{@ticket.title}\""
    ) if @ticket.on_behalf?
    redirect_to @ticket, notice: "Ticket submitted successfully."
  rescue ActiveRecord::RecordInvalid
    flash.now[:alert] = (@ticket.errors.full_messages + @termination_detail.errors.full_messages).to_sentence
    render :new, status: :unprocessable_entity
  end

  # Discards the pending ticket (never persisted) and its session state.
  def cancel_pending
    session.delete(:pending_ticket)
    redirect_to catalogue_tickets_path, notice: "Ticket creation cancelled."
  end

  private

  def set_ticket
    @ticket = Ticket.find(params[:ticket_id])
    unless @ticket.ticket_type == "hiring_departure" && @ticket.metadata["request_type"] == "Termination"
      redirect_to @ticket, alert: "This ticket does not require termination details."
    end
  end

  def set_my_tickets_count
    @my_tickets_count = Ticket.where(customer: current_user).count if current_user.customer?
  end

  def notify_staff_of_new_ticket(ticket)
    User.where(role: %w[agent manager]).active.find_each do |staff|
      TicketNotification.create!(
        ticket:       ticket,
        responded_by: current_user,
        receiver:     staff,
        details:      "New ticket ##{ticket.id} submitted by #{current_user.fullname}: \"#{ticket.title}\"",
        status:       "unread"
      )
    end
  end

  def termination_detail_params
    params.require(:termination_detail).permit(
      :termination_reason, :termination_date, :termination_time,
      :email_address, :key_card, :email_forward_needed,
      :email_forwarded_to, :historical_email_access, :additional_instructions
    )
  end
end
