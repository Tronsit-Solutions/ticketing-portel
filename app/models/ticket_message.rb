class TicketMessage < ApplicationRecord

  MESSAGE_TYPES = %w[customer_reply agent_reply internal_note].freeze

  belongs_to :ticket
  belongs_to :sender, class_name: "User", optional: true

  validates :details,      presence: true
  validates :message_type, inclusion: { in: MESSAGE_TYPES }

  scope :visible,        -> { where.not(message_type: "internal_note") }
  scope :internal_notes, -> { where(message_type: "internal_note") }
  scope :recent,         -> { order(created_at: :asc) }
end
