class TicketNotification < ApplicationRecord

  STATUSES = %w[unread read].freeze

  belongs_to :ticket, optional: true
  belongs_to :responded_by, class_name: "User", optional: true
  belongs_to :receiver,     class_name: "User", optional: true

  validates :status, inclusion: { in: STATUSES }

  scope :unread,    -> { where(status: "unread") }
  scope :read,      -> { where(status: "read") }
  scope :recent,    -> { order(created_at: :desc) }
  scope :for_user,  ->(user) { where(receiver: user) }

  after_create_commit  :broadcast_created
  after_update_commit  :broadcast_badge, if: :saved_change_to_status?

  def unread?
    status == "unread"
  end

  def read?
    status == "read"
  end

  private

  def broadcast_created
    return if receiver.blank?

    broadcast_prepend_later_to [receiver, :ticket_notifications],
      target: "notif-list",
      partial: "ticket_notifications/notification",
      locals: { notification: self }
    broadcast_badge
  end

  def broadcast_badge
    return if receiver.blank?

    badge_class, badge_style =
      if receiver.customer?
        ["ms-auto", nil]
      else
        ["position-absolute", "top:-6px; right:-8px; font-size:9px; padding:2px 5px;"]
      end

    broadcast_replace_later_to [receiver, :ticket_notifications],
      target: "notif-bell-badge",
      partial: "shared/notification_bell_badge",
      locals: { user: receiver, badge_class: badge_class, badge_style: badge_style }

    if receiver.manager?
      broadcast_replace_later_to [receiver, :ticket_notifications],
        target: "notif-bell-badge-sidebar",
        partial: "shared/notification_bell_badge",
        locals: { user: receiver, badge_class: "ms-auto", badge_style: nil, badge_id: "notif-bell-badge-sidebar" }
    end
  end
end
