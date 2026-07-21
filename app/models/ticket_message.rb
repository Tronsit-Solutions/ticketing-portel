class TicketMessage < ApplicationRecord

  MESSAGE_TYPES = %w[customer_reply agent_reply internal_note].freeze

  belongs_to :ticket
  belongs_to :sender, class_name: "User", optional: true

  validates :details,      presence: true
  validates :message_type, inclusion: { in: MESSAGE_TYPES }

  scope :visible,        -> { where(internal_note: false) }
  scope :internal_notes, -> { where(internal_note: true) }
  scope :recent,         -> { order(created_at: :asc) }

  after_create_commit :broadcast_created

  private

  HTML_TAG_PATTERN = /<\s*(p|br|div|span|ul|ol|li|strong|em|a|img|table|tr|td|h[1-6])\b/i

  def broadcast_created
    broadcast_append_later_to [ticket, :messages],
      target: "ticket_messages_agent",
      partial: "ticket_messages/message_agent",
      locals: { message: self } unless details.match?(HTML_TAG_PATTERN)

    return if internal_note?

    broadcast_append_later_to [ticket, :messages],
      target: "ticket_messages_customer",
      partial: "ticket_messages/message_customer",
      locals: { message: self }
  end
end
