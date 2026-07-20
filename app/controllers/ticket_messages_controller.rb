class TicketMessagesController < ApplicationController
  before_action :set_ticket
  before_action :authorize_message!

  def create
    message_type = if current_user.admin? || current_user.agent? || current_user.manager?
      "agent_reply"
    else
      "customer_reply"
    end

    form_data = params[:message_data].presence
    structured = form_data.is_a?(ActionController::Parameters) ? form_data.to_unsafe_h.compact_blank : nil

    @message = @ticket.ticket_messages.build(
      details:         params[:details].presence || structured&.values&.join(", ") || "",
      structured_data: structured.presence,
      message_type:    message_type,
      sender:          current_user,
      internal_note:   params[:internal_note] == "true"
    )

    if @message.save
      if message_type == "agent_reply" && !@message.internal_note?
        @ticket.notify_customer!(
          responded_by: current_user,
          details:      "#{current_user.fullname} replied to your ticket ##{@ticket.id}: \"#{@ticket.title}\""
        )
      end
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
