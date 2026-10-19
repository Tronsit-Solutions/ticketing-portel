class UsersController < ApplicationController
  include UserProfile

  before_action :require_admin!
  before_action :set_user, only: [:show, :update, :destroy, :deactivate, :reset_password, :unlock]

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
    load_user_profile(@user)
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

  def update
    if @user.update(user_params_without_password)
      redirect_back fallback_location: user_path(@user), notice: "User updated successfully."
    else
      redirect_back fallback_location: user_path(@user), alert: @user.errors.full_messages.to_sentence
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
    flash[:temporary_password] = { "name" => @user.fullname, "password" => @user.reset_to_temporary_password! }
    redirect_to user_path(@user)
  end

  def unlock
    @user.unlock_access!
    redirect_to user_path(@user), notice: "#{@user.fullname}'s account has been unlocked."
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
