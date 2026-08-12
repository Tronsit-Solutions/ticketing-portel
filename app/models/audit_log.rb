class AuditLog < ApplicationRecord
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  CREATE          = "created"
  UPDATE          = "updated"
  DESTROY         = "deleted"
  LOGIN           = "login"
  LOGIN_FAILED    = "login_failed"
  LOGOUT          = "logout"
  ASSIGNED        = "assigned"
  STATUS_CHANGED  = "status_changed"
  ENABLED         = "enabled"
  DISABLED        = "disabled"

  ACTIONS = [
    CREATE, UPDATE, DESTROY, LOGIN, LOGIN_FAILED, LOGOUT,
    ASSIGNED, STATUS_CHANGED, ENABLED, DISABLED
  ].freeze

  AUTH     = "auth"
  TICKETS  = "tickets"
  USERS    = "users"
  TEAMS    = "teams"
  SETTINGS = "settings"

  CATEGORIES = [ AUTH, TICKETS, USERS, TEAMS, SETTINGS ].freeze

  CATEGORY_LABELS = {
    AUTH     => "Authentication",
    TICKETS  => "Tickets",
    USERS    => "Users",
    TEAMS    => "Teams",
    SETTINGS => "Settings"
  }.freeze

  ACTION_LABELS = {
    CREATE         => "Created",
    UPDATE         => "Updated",
    DESTROY        => "Deleted",
    LOGIN          => "Signed In",
    LOGIN_FAILED   => "Sign-in Failed",
    LOGOUT         => "Signed Out",
    ASSIGNED       => "Assigned",
    STATUS_CHANGED => "Status Changed",
    ENABLED        => "Enabled",
    DISABLED       => "Disabled"
  }.freeze

  ACTION_BADGES = {
    CREATE         => "success",
    UPDATE         => "info",
    DESTROY        => "danger",
    LOGIN          => "primary",
    LOGIN_FAILED   => "danger",
    LOGOUT         => "secondary",
    ASSIGNED       => "warning",
    STATUS_CHANGED => "info",
    ENABLED        => "success",
    DISABLED       => "secondary"
  }.freeze

  ACTION_ICONS = {
    CREATE         => "bi-plus-circle-fill",
    UPDATE         => "bi-pencil-fill",
    DESTROY        => "bi-trash-fill",
    LOGIN          => "bi-box-arrow-in-right",
    LOGIN_FAILED   => "bi-shield-exclamation",
    LOGOUT         => "bi-box-arrow-right",
    ASSIGNED       => "bi-person-check-fill",
    STATUS_CHANGED => "bi-arrow-repeat",
    ENABLED        => "bi-toggle-on",
    DISABLED       => "bi-toggle-off"
  }.freeze

  validates :action,      inclusion: { in: ACTIONS }
  validates :category,    inclusion: { in: CATEGORIES }
  validates :description, presence: true

  scope :recent,       -> { order(created_at: :desc) }
  scope :in_category,  ->(category) { where(category: category) }
  scope :with_action,  ->(action) { where(action: action) }
  scope :by_actor,     ->(actor_id) { where(actor_id: actor_id) }
  scope :search,       ->(term) {
    where("description ILIKE :t OR actor_name ILIKE :t OR auditable_label ILIKE :t", t: "%#{term}%")
  }
  scope :between_dates, ->(from, to) {
    scope = all
    scope = scope.where("created_at >= ?", from.to_date.beginning_of_day) if from.present?
    scope = scope.where("created_at <= ?", to.to_date.end_of_day) if to.present?
    scope
  }

  def action_label
    ACTION_LABELS[action] || action.humanize
  end

  def category_label
    CATEGORY_LABELS[category] || category.humanize
  end

  def badge_color
    ACTION_BADGES[action] || "secondary"
  end

  def icon
    ACTION_ICONS[action] || "bi-clock-history"
  end

  def self.record!(actor:, action:, category:, description:, auditable: nil, changed_data: {}, request: nil)
    create!(
      actor:           actor,
      actor_name:      actor&.fullname.presence || "System",
      actor_role:      actor&.role,
      action:           action,
      category:         category,
      auditable:        auditable,
      auditable_label:  auditable.try(:audit_label),
      description:      description,
      changed_data:     changed_data || {},
      ip_address:       request&.remote_ip,
      user_agent:       request&.user_agent
    )
  rescue => e
    Rails.logger.error("[AuditLog] failed to record: #{e.message}")
  end
end
