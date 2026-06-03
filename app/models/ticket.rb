class Ticket < ApplicationRecord

  STATUSES = %w[open in_progress closed cancelled].freeze

  TICKET_TYPES = %w[
    technical_support
    carecloud
    ehr_change
    bright_ideas
    great_work
    hr
    hiring
    termination
  ].freeze

  # Associations
  belongs_to :location,    optional: true
  belongs_to :customer,    class_name: "User", optional: true
  belongs_to :assignee,    class_name: "User", optional: true
  belongs_to :assigned_by, class_name: "User", optional: true
  belongs_to :resolved_by, class_name: "User", optional: true

  has_many :ticket_assignments,   dependent: :destroy
  has_many :ticket_details,       dependent: :destroy
  has_many :ticket_files,         dependent: :destroy
  has_many :ticket_notifications, dependent: :destroy

  # Validations
  validates :title,       presence: true
  validates :ticket_type, inclusion: { in: TICKET_TYPES }
  validates :status,      inclusion: { in: STATUSES }

  # Scopes
  scope :open,        -> { where(status: "open") }
  scope :in_progress, -> { where(status: "in_progress") }
  scope :closed,      -> { where(status: "closed") }
  scope :cancelled,   -> { where(status: "cancelled") }
  scope :unassigned,  -> { where(assignee_id: nil) }
  scope :assigned,    -> { where.not(assignee_id: nil) }
  scope :recent,      -> { order(created_at: :desc) }

  # Callbacks
  before_update :set_resolved_at, if: :status_changed_to_closed?

  private

  def status_changed_to_closed?
    status_changed? && status.in?(%w[closed cancelled])
  end

  def set_resolved_at
    self.resolved_at = Time.current
  end

end
