# Serves ticket attachments only to signed-in users who may view the ticket.
# Replaces Active Storage's own blob routes (switched off in application.rb),
# whose signed URLs worked for anyone holding the link, logged in or not.
class TicketAttachmentsController < ApplicationController
  include ActiveStorage::Streaming

  before_action :set_ticket
  before_action :authorize_show!

  def show
    attachment = @ticket.attachments.find(params[:id])
    send_blob_stream attachment.blob, disposition: params[:disposition]
  end

  private

  def set_ticket
    @ticket = Ticket.find(params[:ticket_id])
  end

  # Same rule as viewing the ticket itself.
  def authorize_show!
    return if current_user.admin? || current_user.manager? || current_user.agent?

    unauthorized! unless @ticket.customer == current_user
  end
end
