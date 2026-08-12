Warden::Manager.after_failed_fetch do |user, auth, opts|
  next unless opts[:scope] == :user

  request = ActionDispatch::Request.new(auth.env)
  email   = request.params.dig("user", "email")

  AuditLog.record!(
    actor:       nil,
    action:      AuditLog::LOGIN_FAILED,
    category:    AuditLog::AUTH,
    description: "Failed sign-in attempt#{" for #{email}" if email.present?}",
    changed_data: { "email" => email }.compact,
    request:     request
  )
end
