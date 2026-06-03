class TicketDetailsController < ApplicationController
  before_action :set_ticket

  def create
    message_type = if (current_user.admin? || current_user.agent?) && params[:ticket_detail][:message_type] == "internal_note"
      "internal_note"
    elsif current_user.admin? || current_user.agent?
      "agent_reply"
    else
      "customer_reply"
    end

    @detail = @ticket.ticket_details.build(
      details:      params[:ticket_detail][:details],
      message_type: message_type,
      sender:       current_user
    )

    if @detail.save
      redirect_to ticket_path(@ticket), notice: "Reply added."
    else
      redirect_to ticket_path(@ticket), alert: "Could not add reply."
    end
  end

  private

  def set_ticket
    @ticket = Ticket.find(params[:ticket_id])
  end
end
