class Agent::UsersController < ApplicationController
  before_action :require_admin_or_agent!
  before_action :set_user, only: [:show, :edit, :update]
  layout "agent"

  def index
    @users = User.where(role: %w[agent customer])
    @users = @users.where(role: params[:role]) if params[:role].in?(%w[agent customer])
    @users = @users.where(is_active: params[:status]) if params[:status].in?(%w[true false])
    if params[:search].present?
      term   = "%#{params[:search].strip}%"
      @users = @users.where("fullname ILIKE :term OR email ILIKE :term", term: term)
    end
    @users = @users.order(fullname: :asc, email: :asc).page(params[:page]).per(25)
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
      redirect_to agent_users_path, notice: "#{@user.role.humanize} created successfully."
    else
      @role = @user.role
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def show
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
      redirect_to agent_user_path(@user), notice: "#{@user.role.humanize} updated successfully."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
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
