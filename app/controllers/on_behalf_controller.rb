class OnBehalfController < ApplicationController
  before_action :require_admin_or_agent!

  def new
    @ticket    = Ticket.new
    @customers = User.customers.active.order(:fullname)
  end

  def create
    customer = User.find(params[:ticket][:customer_id])

    @ticket             = Ticket.new(on_behalf_ticket_params)
    @ticket.customer    = customer
    @ticket.created_by  = current_user
    @ticket.assignee    = current_user
    @ticket.assigned_by = current_user
    @ticket.assigned_at = Time.current
    @ticket.status      = "in_progress"
    @ticket.title       = "On behalf of #{customer.fullname} — #{params[:ticket][:title]}"

    if @ticket.save
      TicketAssignment.create!(
        ticket:        @ticket,
        assigned_to:   current_user,
        assigned_from: nil,
        assigned_by:   current_user,
        reason:        "Created on behalf of #{customer.fullname}"
      )
      TicketNotification.create!(
        ticket:       @ticket,
        responded_by: current_user,
        receiver:     customer,
        details:      "A ticket has been submitted on your behalf: #{@ticket.title}",
        status:       "unread"
      )
      redirect_to ticket_path(@ticket), notice: "Ticket created on behalf of #{customer.fullname}."
    else
      @customers = User.customers.active.order(:fullname)
      render :new, status: :unprocessable_entity
    end
  end

  private

  def on_behalf_ticket_params
    params.require(:ticket).permit(:ticket_type, :title, :location_id)
  end
end
