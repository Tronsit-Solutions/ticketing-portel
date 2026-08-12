# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  layout false

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
