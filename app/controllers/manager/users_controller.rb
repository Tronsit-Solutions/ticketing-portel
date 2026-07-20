class Manager::UsersController < ApplicationController
  before_action :require_admin_or_manager!
  before_action :set_user, only: [:edit, :update, :destroy, :deactivate, :activate, :reset_password]
  layout "manager"

  RESET_PASSWORD = "123456".freeze

  def index
    @customers = User.customers
    @customers = @customers.where(is_active: params[:active]) if params[:active].present?
    if params[:search].present?
      term       = "%#{params[:search].strip}%"
      @customers = @customers.where("fullname ILIKE :term OR email ILIKE :term", term: term)
    end

    sort_column    = params[:sort] == "name" ? :fullname : :created_at
    sort_direction = params[:direction] == "asc" ? :asc : :desc
    @sort          = params[:sort]
    @direction     = params[:direction].presence || "desc"
    order_clause   = params[:sort].present? ? { sort_column => sort_direction } : { fullname: :asc, email: :asc }
    @customers     = @customers.order(order_clause).page(params[:page]).per(25)
  end

  def new
    @role = params[:role]
  end

  def create
    @user = User.new(user_params)

    if @user.role == "agent" && @user.team_id.blank?
      @user.team_id = current_user.team_id
    end

    if @user.save
      redirect_to manager_root_path, notice: "#{@user.role.humanize} created successfully."
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

  def edit; end

  def update
    if @user.update(user_params_without_password)
      redirect_to manager_user_path(@user), notice: "Customer updated successfully."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @user.destroy
    redirect_to manager_users_path, notice: "Customer deleted."
  end

  def deactivate
    @user.update!(is_active: false)
    redirect_to manager_users_path, notice: "#{@user.fullname} has been deactivated."
  end

  def activate
    @user.update!(is_active: true)
    redirect_to manager_users_path, notice: "#{@user.fullname} has been activated."
  end

  def reset_password
    @user.update!(password: RESET_PASSWORD, password_confirmation: RESET_PASSWORD)
    redirect_to manager_users_path, notice: "#{@user.fullname}'s password has been reset to the default password."
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:fullname, :email, :password, :password_confirmation, :role, :contact_no, :address, :team_id, :is_active)
  end

  def user_params_without_password
    params.require(:user).permit(:fullname, :email, :contact_no, :address, :is_active)
  end
end
