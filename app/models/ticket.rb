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
        { type: "hr",      label: "General HR",                   icon: "bi-people",      desc: "Human resources inquiries, policies, and requests"        },
        { type: "hiring",  label: "New Team Member or Departure", icon: "bi-person-plus", desc: "Submit a request for a new hire or team member departure" },
      ]
    },
    { type: "lms",               label: "LMS",               icon: "bi-mortarboard",  desc: "Reset password request for LMS"                                       },
  ].freeze

  # Single source of truth — derived from CATALOGUE, never out of sync.
  # "departure" has no catalogue tile of its own — it shares the "hiring" tile/form
  # (see TicketsController#create, which resolves the real stored type from the
  # "Hiring or Termination?" dropdown) — so it's added in here explicitly.
  TICKET_TYPES = CATALOGUE.flat_map { |c| c[:children] || [c] }.map { |c| c[:type] }.freeze + ["departure"]
  TYPE_LABELS  = CATALOGUE.flat_map { |c| c[:children] || [c] }.each_with_object({}) { |c, h| h[c[:type]] = c[:label] }.merge(
    "hiring"   => "Hiring",
    "departure" => "Departure"
  ).freeze

  # Ticket types whose creation form has no Title input — their title
  # is derived from the ticket type instead of user input.
  TITLELESS_TYPES = %w[bright_ideas great_work hr hiring departure lms].freeze

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
  scope :hiring,      -> { where(ticket_type: "hiring") }
  scope :departure,   -> { where(ticket_type: "departure") }

  def departure?
    ticket_type == "departure"
  end

  def hiring?
    ticket_type == "hiring"
  end

  def type_label
    TYPE_LABELS[ticket_type] || ticket_type.humanize
  end

  def on_behalf?
    created_by.present?
  end

  def resolution_duration
    return nil unless status == "closed" && assigned_at.present? && resolved_at.present?

    seconds = (resolved_at - assigned_at).to_i
    return nil if seconds.negative?

    if seconds < 60
      "#{seconds}s"
    elsif seconds < 3600
      "#{seconds / 60}m"
    elsif seconds < 86_400
      "#{seconds / 3600}h #{(seconds % 3600) / 60}m"
    else
      "#{seconds / 86_400}d #{(seconds % 86_400) / 3600}h"
    end
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
    self.title = type_label if TITLELESS_TYPES.include?(ticket_type) && title.blank?
  end

  def status_changed_to_closed?
    status_changed? && status.in?(%w[closed cancelled])
  end

  def set_resolved_at
    self.resolved_at = Time.current
  end

end
