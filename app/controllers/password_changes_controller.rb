# Where a user whose password was reset by staff chooses their own before
# they can use the app (see ApplicationController#require_password_change).
class PasswordChangesController < ApplicationController
  layout "auth"

  def edit
    redirect_to root_path unless current_user.must_change_password?
  end

  def update
    password, confirmation = params.require(:user).values_at(:password, :password_confirmation)

    if current_user.valid_password?(password)
      current_user.errors.add(:password, "must be different from your temporary password")
    elsif current_user.update(password: password, password_confirmation: confirmation, must_change_password: false)
      # Changing the password invalidates the current session; keep them signed in.
      bypass_sign_in(current_user)
      return redirect_to root_path, notice: "Your password has been changed."
    end

    render :edit, status: :unprocessable_entity
  end
end
