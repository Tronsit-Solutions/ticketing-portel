class Agent::UsersController < ApplicationController
  before_action :require_admin_or_agent!
  layout "agent"

  def index
    @users = User.where(role: %w[agent customer])
    @users = @users.where(role: params[:role]) if params[:role].in?(%w[agent customer])
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

  private

  def user_params
    params.require(:user).permit(:fullname, :email, :password, :password_confirmation, :role, :contact_no, :address, :team_id, :is_active)
  end
end
