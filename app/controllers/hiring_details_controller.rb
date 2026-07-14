class HiringDetailsController < ApplicationController
  before_action :set_ticket

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

  private

  def set_ticket
    @ticket = Ticket.find(params[:ticket_id])
    unless @ticket.ticket_type == "hiring_departure"
      redirect_to @ticket, alert: "This ticket does not require hiring details."
    end
  end

  def hiring_detail_params
    params.require(:hiring_detail).permit(
      :start_date, :date_of_birth, :title_position, :is_provider,
      :department, :gender, :cell_phone, :badge_number,
      :credentials_send_to, :existing_pc_user, :additional_info,
      :pc_requirement, :microsoft_teams_department,
      access_systems: [], distribution_groups: []
    )
  end
end
