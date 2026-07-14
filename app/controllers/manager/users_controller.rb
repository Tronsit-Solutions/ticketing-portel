class Manager::UsersController < ApplicationController
  before_action :require_admin_or_manager!
  layout "manager"

  def new
    @role = params[:role]
  end

  def create
    @user = User.new(user_params)

    if @user.role == "agent" && @user.team_id.blank?
      @user.team_id = current_user.team_id
    end

    if @user.save
      redirect_to manager_root_path, notice: "User created successfully."
    else
      @role = @user.role
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @user = User.find(params[:id])
    @assigned_tickets = @user.assigned_tickets.recent.includes(:customer, :location)
    @open_count       = @user.assigned_tickets.open.count + @user.assigned_tickets.in_progress.count
    @closed_count     = @user.assigned_tickets.closed.count
    @total_count      = @user.assigned_tickets.count

    @assigned_tickets = @assigned_tickets.where(status: params[:status]) if params[:status].present?
    @assigned_tickets = @assigned_tickets.page(params[:page]).per(25)
  end

  private

  def user_params
    params.require(:user).permit(:fullname, :email, :password, :password_confirmation, :role, :contact_no, :address, :team_id, :is_active)
  end
end
