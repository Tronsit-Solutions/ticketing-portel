class HiringDetailsController < ApplicationController
  before_action :set_ticket, only: [:new, :create]
  before_action :set_my_tickets_count, only: [:new, :create, :new_pending, :create_pending]

  def new
    if @ticket.hiring_detail.present?
      redirect_to @ticket, notice: "Hiring details already submitted."
      return
    end
    @hiring_detail = @ticket.build_hiring_detail
  end

  def create
    if @ticket.hiring_detail.present?
      redirect_to @ticket, notice: "Hiring details already submitted."
      return
    end

    @hiring_detail = @ticket.build_hiring_detail(hiring_detail_params)

    if @hiring_detail.save
      redirect_to @ticket, notice: "Hiring details submitted successfully."
    else
      flash.now[:alert] = @hiring_detail.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  # Step 2 of the new-ticket flow: the ticket itself has not been persisted
  # yet (see TicketsController#create) — it lives in the session until this
  # form is submitted, so both the ticket and its hiring detail are created
  # together, or neither is.
  def new_pending
    @ticket = build_pending_ticket
    return redirect_to new_ticket_path, alert: "Your ticket details expired. Please start again." unless @ticket

    @hiring_detail = @ticket.build_hiring_detail
    render :new
  end

  def create_pending
    @ticket = build_pending_ticket
    return redirect_to new_ticket_path, alert: "Your ticket details expired. Please start again." unless @ticket

    @hiring_detail = @ticket.build_hiring_detail(hiring_detail_params)

    ActiveRecord::Base.transaction do
      @ticket.save!
      @hiring_detail.save!
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
    flash.now[:alert] = (@ticket.errors.full_messages + @hiring_detail.errors.full_messages).to_sentence
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
    unless @ticket.ticket_type == "hiring_departure"
      redirect_to @ticket, alert: "This ticket does not require hiring details."
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

  def hiring_detail_params
    params.require(:hiring_detail).permit(
      :start_date, :date_of_birth, :title_position, :is_provider,
      :billing_provider_name, :provider_npi, :q5_q6_modifier_required, :q5_q6_modifier,
      :department, :gender, :cell_phone, :badge_number,
      :credentials_send_to, :existing_pc_user, :additional_info,
      :pc_requirement,
      access_systems: [], distribution_groups: [], microsoft_teams_department: []
    )
  end
end
