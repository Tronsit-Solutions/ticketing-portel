# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  skip_before_action :authenticate_user!
  layout false

  # A failed sign-in re-renders this action with the submitted params, so the
  # entered email tells us whether to show the unlock countdown.
  def new
    email = params.dig(:user, :email)
    @unlocks_at = User.find_for_authentication(email: email)&.unlocks_at if email.present?
    super
  end

  def create
    super do |user|
      AuditLog.record!(
        actor:       user,
        action:      AuditLog::LOGIN,
        category:    AuditLog::AUTH,
        description: "#{user.fullname} signed in",
        request:     request
      )
    end
  end

  def destroy
    user = current_user
    super do
      AuditLog.record!(
        actor:       user,
        action:      AuditLog::LOGOUT,
        category:    AuditLog::AUTH,
        description: "#{user.fullname} signed out",
        request:     request
      )
    end
  end

  def after_sign_out_path_for(resource_or_scope)
    new_user_session_path
  end

end
