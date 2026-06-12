class UsersController < ApplicationController
  before_action :require_admin!
  before_action :set_user, only: [:show, :edit, :update, :destroy, :deactivate]

  def index
    @users = User.includes(:team).order(:fullname)
    @users = @users.where(role: params[:role])          if params[:role].present?
    @users = @users.where(is_active: params[:active])   if params[:active].present?
  end

  # def show
  #   if @user.agent? || @user.manager?
  #     @assigned_tickets = @user.assigned_tickets.recent.includes(:customer, :location)
  #     @open_count       = @user.assigned_tickets.open.count + @user.assigned_tickets.in_progress.count
  #     @closed_count     = @user.assigned_tickets.closed.count
  #     @total_count      = @user.assigned_tickets.count

  #     @assigned_tickets = @assigned_tickets.where(status: params[:status]) if params[:status].present?
  #   end
  # end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to users_path, notice: "User created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @user.update(user_params_without_password)
      redirect_to user_path(@user), notice: "User updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @user.destroy
    redirect_to users_path, notice: "User deleted."
  end

  def deactivate
    @user.update!(is_active: false)
    redirect_to users_path, notice: "#{@user.fullname} has been deactivated."
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(
      :fullname, :email, :password, :password_confirmation,
      :role, :team_id, :contact_no, :address, :is_active
    )
  end

  def user_params_without_password
    params.require(:user).permit(
      :fullname, :email, :role, :team_id, :contact_no, :address, :is_active
    )
  end
end
