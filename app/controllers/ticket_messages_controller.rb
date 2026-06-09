class TicketMessagesController < ApplicationController
  before_action :set_ticket

  def create
    message_type = if (current_user.admin? || current_user.agent?) && params[:ticket_message][:message_type] == "internal_note"
      "internal_note"
    elsif current_user.admin? || current_user.agent?
      "agent_reply"
    else
      "customer_reply"
    end
    @message = @ticket.ticket_messages.build(
      details:      params[:details],
      message_type: message_type,
      sender:       current_user
    )

    if @message.save
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
