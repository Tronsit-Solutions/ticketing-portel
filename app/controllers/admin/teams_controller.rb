class Admin::TeamsController < ApplicationController
  before_action :require_admin!

  SORT_COLUMNS = { "name" => :fullname, "email" => :email }.freeze

  def index
    @agents = User.agents
    @agents = @agents.where(is_active: params[:active]) if params[:active].present?
    if params[:search].present?
      term    = "%#{params[:search].strip}%"
      @agents = @agents.where("fullname ILIKE :term OR email ILIKE :term", term: term)
    end

    @sort      = SORT_COLUMNS.key?(params[:sort]) ? params[:sort] : "name"
    @direction = params[:direction] == "desc" ? "desc" : "asc"
    @agents    = @agents.order(SORT_COLUMNS[@sort] => @direction).page(params[:page]).per(25)
  end

  def new
    @user = User.new(role: "agent")
  end

  def create
    @user = User.new(user_params)
    @user.role = "agent"

    if @user.save
      redirect_to admin_teams_path, notice: "Agent created successfully."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:fullname, :email, :password, :password_confirmation, :contact_no, :address, :team_id, :is_active)
  end
end
