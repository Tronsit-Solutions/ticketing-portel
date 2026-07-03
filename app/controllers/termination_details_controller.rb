class TerminationDetailsController < ApplicationController
  before_action :set_ticket

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
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_ticket
    @ticket = Ticket.find(params[:ticket_id])
    unless @ticket.ticket_type == "hiring_departure" && @ticket.metadata["request_type"] == "Termination"
      redirect_to @ticket, alert: "This ticket does not require termination details."
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
