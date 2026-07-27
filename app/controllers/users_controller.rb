class UsersController < ApplicationController
  before_action :require_admin!
  before_action :set_user, only: [:show, :edit, :update, :destroy, :deactivate, :reset_password]

  RESET_PASSWORD = "123456".freeze

  SORT_COLUMNS = { "name" => :fullname, "email" => :email }.freeze

  def index
    @users = User.includes(:team)
    @users = @users.where(role: params[:role])          if params[:role].present?
    @users = @users.where(is_active: params[:active])   if params[:active].present?
    if params[:search].present?
      term   = "%#{params[:search].strip}%"
      @users = @users.where("fullname ILIKE :term OR email ILIKE :term", term: term)
    end

    @sort  = SORT_COLUMNS.key?(params[:sort]) ? params[:sort] : "name"
    @direction = params[:direction] == "desc" ? "desc" : "asc"
    @users = @users.order(SORT_COLUMNS[@sort] => @direction).page(params[:page]).per(25)
  end

  def show
    if @user.agent? || @user.manager?
      @assigned_tickets = @user.assigned_tickets.recent.includes(:customer, :location)
      @open_count       = @user.assigned_tickets.open.count + @user.assigned_tickets.in_progress.count
      @closed_count     = @user.assigned_tickets.closed.count
      @total_count      = @user.assigned_tickets.count

      @assigned_tickets = @assigned_tickets.where(status: params[:status]) if params[:status].present?
      @assigned_tickets = @assigned_tickets.page(params[:page]).per(25)
    end
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to users_path, notice: "User created successfully."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @user.update(user_params_without_password)
      redirect_to user_path(@user), notice: "User updated successfully."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
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

  def reset_password
    @user.update!(password: RESET_PASSWORD, password_confirmation: RESET_PASSWORD)
    redirect_to user_path(@user), notice: "#{@user.fullname}'s password has been reset to the default password."
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
