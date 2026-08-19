Warden::Manager.before_failure do |env, opts|
  next unless opts[:scope] == :user

  request = ActionDispatch::Request.new(env)
  # Warden rewrites PATH_INFO to the failure action (e.g. "/unauthenticated")
  # before this hook runs, so the original request path must be read from
  # attempted_path instead. Only a rejected sign-in POST is a real failed
  # login attempt — the same Warden failure path also fires for e.g. an
  # anonymous visit to a protected page, which isn't a login attempt at all.
  attempted_path = opts[:attempted_path].to_s.split("?").first
  next unless request.post? && attempted_path == Rails.application.routes.url_helpers.new_user_session_path

  email = request.params.dig("user", "email")

  AuditLog.record!(
    actor:       nil,
    action:      AuditLog::LOGIN_FAILED,
    category:    AuditLog::AUTH,
    description: "Failed sign-in attempt#{" for #{email}" if email.present?}",
    changed_data: { "email" => email }.compact,
    request:     request
  )
end
