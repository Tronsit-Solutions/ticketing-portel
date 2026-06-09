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
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:fullname, :email, :password, :password_confirmation, :role, :contact_no, :address, :team_id, :is_active)
  end
end
