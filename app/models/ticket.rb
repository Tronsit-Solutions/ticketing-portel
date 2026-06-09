class Ticket < ApplicationRecord

  STATUSES = %w[open in_progress closed cancelled].freeze

  TICKET_TYPES = %w[
    technical_support
    tronshealth
    carecloud
    curemd
    bright_ideas
    great_work
    hr
    hiring_departure
    lms
  ].freeze

  CATALOGUE = [
    { type: "technical_support", label: "Technical Support", icon: "bi-headset",      desc: "Report any IT related issues here"         },
    { type: "tronshealth",       label: "TronsHealth",       icon: "bi-activity",     desc: "Report any issues related to Tronshealth here"                  },
    { type: "carecloud",         label: "CareCloud",         icon: "bi-cloud",        desc: "Report any issues related to CareCloud here(Phoenix, AZ Users only)"      },
    { type: "curemd",            label: "CureMD",            icon: "bi-arrow-repeat", desc: "Report any issues related to CureMD here"         },
    { type: "bright_ideas",      label: "Bright Ideas",      icon: "bi-lightbulb",    desc: "Share To Aware"       },
    { type: "great_work",        label: "Great Work",        icon: "bi-briefcase",    desc: "Your Appreciation Is Appreciated"          },
    {
      label: "Human Resources",
      icon:  "bi-people",
      desc:  "HR inquiries, new hires, departures, and policy requests",
      children: [
        { type: "hr",               label: "General HR",                   desc: "Human resources inquiries, policies, and requests"            },
        { type: "hiring_departure", label: "New Team Member or Departure", desc: "Submit a request for a new hire or team member departure"     },
      ]
    },
    { type: "lms",               label: "LMS",               icon: "bi-mortarboard",  desc: "Reset password request for LMS"     },
  ].freeze

  # Associations
  belongs_to :location,    optional: true
  belongs_to :customer,    class_name: "User", optional: true
  belongs_to :assignee,    class_name: "User", optional: true
  belongs_to :assigned_by, class_name: "User", optional: true
  belongs_to :resolved_by,  class_name: "User", optional: true
  belongs_to :created_by,   class_name: "User", optional: true

  has_many :ticket_assignments,   dependent: :destroy
  has_many :ticket_messages,      dependent: :destroy
  has_many :ticket_files,         dependent: :destroy
  has_many :ticket_notifications, dependent: :destroy

  # Validations
  validates :title,       presence: true
  validates :ticket_type, inclusion: { in: TICKET_TYPES }
  validates :status,      inclusion: { in: STATUSES }

  # Metadata accessor helpers
  def details
    metadata["details"]
  end

  def details=(val)
    self.metadata = (metadata || {}).merge("details" => val)
  end

  # Scopes
  scope :open,        -> { where(status: "open") }
  scope :in_progress, -> { where(status: "in_progress") }
  scope :closed,      -> { where(status: "closed") }
  scope :cancelled,   -> { where(status: "cancelled") }
  scope :unassigned,  -> { where(assignee_id: nil) }
  scope :assigned,    -> { where.not(assignee_id: nil) }
  scope :recent,      -> { order(created_at: :desc) }

  def on_behalf?
    created_by.present?
  end

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
