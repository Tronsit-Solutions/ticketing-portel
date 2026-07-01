class TicketMessagesController < ApplicationController
  before_action :set_ticket
  before_action :authorize_message!

  def create
    message_type = if current_user.admin? || current_user.agent?
      "agent_reply"
    else
      "customer_reply"
    end

    @message = @ticket.ticket_messages.build(
      details:      params[:details],
      message_type: message_type,
      sender:       current_user,
      internal_note: params[:internal_note] == "true"
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

  def authorize_message!
    unless current_user.admin? || @ticket.assignee == current_user || @ticket.customer == current_user
      unauthorized!
    end
  end
end
