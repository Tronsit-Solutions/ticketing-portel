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
  scope :hiring,      -> { where(ticket_type: "hiring_departure").where.not("metadata ->> 'request_type' = ?", "Termination") }
  scope :departure,   -> { where(ticket_type: "hiring_departure").where("metadata ->> 'request_type' = ?", "Termination") }

  def departure?
    ticket_type == "hiring_departure" && metadata["request_type"] == "Termination"
  end

  def hiring?
    ticket_type == "hiring_departure" && !departure?
  end

  # Display label for the Type column/filter — splits the single
  # "hiring_departure" ticket_type into Hiring vs Departure.
  def type_label
    return "Departure" if departure?
    return "Hiring"    if hiring?

    ticket_type.humanize
  end

  def on_behalf?
    created_by.present?
  end

  # Agents submitting a ticket on a customer's behalf are auto self-assigned;
  # managers are not, since they typically triage rather than work tickets themselves.
  def auto_self_assign_for_agent!
    return unless on_behalf? && created_by.agent?

    update!(
      assignee:    created_by,
      assigned_by: created_by,
      assigned_at: Time.current,
      status:      "in_progress"
    )
    ticket_assignments.create!(
      assigned_to: created_by,
      assigned_by: created_by,
      reason:      "Self-assigned"
    )
  end

  def notify_customer!(details:, responded_by:)
    return if customer.blank? || customer == responded_by

    ticket_notifications.create!(
      responded_by: responded_by,
      receiver:     customer,
      details:      details,
      status:       "unread"
    )
  end

  def notify_staff!(details:, responded_by:)
    receivers = User.where(role: "manager").active.to_a
    receivers << assignee if assignee.present?

    receivers.uniq.reject { |user| user == responded_by }.each do |staff|
      ticket_notifications.create!(
        responded_by: responded_by,
        receiver:     staff,
        details:      details,
        status:       "unread"
      )
    end
  end

  # Callbacks
  before_update        :set_resolved_at, if: :status_changed_to_closed?
  after_create_commit  :broadcast_unassigned_badge, if: :unassigned?
  after_update_commit  :broadcast_unassigned_badge, if: :saved_change_to_assignee_id?

  private

  def unassigned?
    assignee_id.nil?
  end

  def broadcast_unassigned_badge
    broadcast_replace_to :unassigned_tickets,
      target:  "unassigned-ticket-badge",
      partial: "shared/unassigned_ticket_badge"
  end

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
