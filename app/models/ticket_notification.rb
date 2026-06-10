class TicketNotification < ApplicationRecord
  STATUSES = %w[unread read].freeze

  belongs_to :ticket
  belongs_to :responded_by, class_name: "User", optional: true
  belongs_to :receiver,     class_name: "User", optional: true

  validates :status, inclusion: { in: STATUSES }

  scope :unread,    -> { where(status: "unread") }
  scope :read,      -> { where(status: "read") }
  scope :recent,    -> { order(created_at: :desc) }
  scope :for_user,  ->(user) { where(receiver: user) }

  def unread?
    status == "unread"
  end

  def read?
    status == "read"
  end
end
