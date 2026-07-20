class PasswordResetRequestsController < ApplicationController
  skip_before_action :authenticate_user!
  layout false

  def new; end

  def create
    email = params[:email].to_s.strip
    user  = User.find_by("lower(email) = ?", email.downcase)

    if user.present?
      User.where(role: %w[admin manager]).active.find_each do |staff|
        TicketNotification.create!(
          receiver:     staff,
          responded_by: user,
          details:      "#{user.fullname} (#{user.email}) has requested a password reset.",
          status:       "unread"
        )
      end
    end

    redirect_to new_password_reset_request_path, notice: "If an account exists for that email, our team has been notified and will reset your password shortly."
  end
end
