class TeamsNotificationJob < ApplicationJob
  queue_as :default

  def perform(**message)
    TeamsNotifier.deliver(**message)
  rescue StandardError => e
    # A Teams outage must never surface to the user — the in-app
    # notification has already been created by the time this runs.
    Rails.logger.error("[TeamsNotificationJob] failed: #{e.class} #{e.message}")
  end
end
