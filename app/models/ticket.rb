class Ticket < ApplicationRecord

  STATUSES = %w[open in_progress closed cancelled].freeze

  CATALOGUE = [
    { type: "technical_support", label: "Technical Support", icon: "bi-headset",      desc: "Report any IT related issues here"                                    },
    { type: "tronshealth",       label: "TronsHealth",       icon: "bi-activity",     desc: "Report any issues related to Tronshealth here"                        },
    { type: "carecloud",         label: "CareCloud",         icon: "bi-cloud",        desc: "Report any issues related to CareCloud here (Phoenix, AZ Users only)" },
    { type: "curemd",            label: "CureMD",            icon: "bi-arrow-repeat", desc: "Report any issues related to CureMD here"                             },
    { type: "bright_ideas",      label: "Bright Ideas",      icon: "bi-lightbulb",    desc: "Share To Aware"                                                       },
    { type: "great_work",        label: "Great Work",        icon: "bi-briefcase",    desc: "Your Appreciation Is Appreciated"                                     },
    {
      label: "Human Resources",
      icon:  "bi-people",
      desc:  "HR inquiries, new hires, departures, and policy requests",
      children: [
        { type: "hr",               label: "General HR",                   icon: "bi-people",      desc: "Human resources inquiries, policies, and requests"        },
        { type: "hiring_departure", label: "New Team Member or Departure", icon: "bi-person-plus", desc: "Submit a request for a new hire or team member departure" },
      ]
    },
    { type: "lms",               label: "LMS",               icon: "bi-mortarboard",  desc: "Reset password request for LMS"                                       },
  ].freeze

  # Single source of truth — derived from CATALOGUE, never out of sync
  TICKET_TYPES = CATALOGUE.flat_map { |c| c[:children] || [c] }.map { |c| c[:type] }.freeze

  # Associations
  belongs_to :location,    optional: true
  belongs_to :customer,    class_name: "User", optional: true
  belongs_to :assignee,    class_name: "User", optional: true
  belongs_to :assigned_by, class_name: "User", optional: true
  belongs_to :resolved_by,  class_name: "User", optional: true
  belongs_to :created_by,   class_name: "User", optional: true

  has_many  :ticket_assignments,   dependent: :destroy
  has_many  :ticket_messages,      dependent: :destroy
  has_many  :ticket_notifications, dependent: :destroy
  has_one   :hiring_detail,        dependent: :destroy
  has_one   :termination_detail,   dependent: :destroy

  has_many_attached :attachments

  before_validation :auto_title_for_bright_ideas

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

  def auto_title_for_bright_ideas
    if ticket_type == "bright_ideas" && title.blank?
      idea_types = Array(metadata&.dig("idea_types")).reject(&:blank?)
      self.title = idea_types.any? ? "Bright Idea: #{idea_types.join(', ')}" : "Bright Idea"
    elsif ticket_type == "great_work" && title.blank?
      work_types = Array(metadata&.dig("work_types")).reject(&:blank?)
      self.title = work_types.any? ? "Great Work: #{work_types.join(', ')}" : "Great Work"
    elsif ticket_type == "hr" && title.blank?
      hr_types = Array(metadata&.dig("hr_types")).reject(&:blank?)
      self.title = hr_types.any? ? "General HR: #{hr_types.first}" : "General HR"
    elsif ticket_type == "lms" && title.blank?
      self.title = "Password Reset for LMS"
    elsif ticket_type == "hiring_departure" && title.blank?
      request_type = metadata&.dig("request_type").presence || "Request"
      full_name    = metadata&.dig("full_name").presence
      self.title   = full_name ? "#{request_type}: #{full_name}" : request_type
    end
  end

  def status_changed_to_closed?
    status_changed? && status.in?(%w[closed cancelled])
  end

  def set_resolved_at
    self.resolved_at = Time.current
  end

end
