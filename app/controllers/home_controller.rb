class HomeController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    if user_signed_in?
      redirect_to after_sign_in_path_for(current_user)
    else
      redirect_to new_user_session_path
    end
  end
end
