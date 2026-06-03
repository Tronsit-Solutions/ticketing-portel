class TicketAssignment < ApplicationRecord
  belongs_to :ticket
  belongs_to :assigned_to,   class_name: "User"
  belongs_to :assigned_from, class_name: "User", optional: true
  belongs_to :assigned_by,   class_name: "User"

  scope :recent,   -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(assigned_to: user) }
end
