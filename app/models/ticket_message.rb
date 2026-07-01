class TicketMessage < ApplicationRecord

  MESSAGE_TYPES = %w[customer_reply agent_reply internal_note].freeze

  belongs_to :ticket
  belongs_to :sender, class_name: "User", optional: true

  validates :details,      presence: true
  validates :message_type, inclusion: { in: MESSAGE_TYPES }

  scope :visible,        -> { where(internal_note: false) }
  scope :internal_notes, -> { where(internal_note: true) }
  scope :recent,         -> { order(created_at: :asc) }
end
