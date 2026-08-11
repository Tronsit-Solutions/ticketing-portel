class DropdownOption < ApplicationRecord
  # Ticket Forms
  HR_TYPES             = "hr_types"
  IDEA_TYPES           = "idea_types"
  WORK_TYPES           = "work_types"
  CARECLOUD_ISSUE      = "carecloud_issue"
  CUREMD_ISSUE         = "curemd_issue"
  TRONSHEALTH_ISSUE    = "tronshealth_issue"
  EHR_CHANGE_ISSUE     = "ehr_change_issue"

  # Hiring & Termination
  HIRING_TITLE_POSITION      = "hiring_title_position"
  HIRING_DEPARTMENT          = "hiring_department"
  HIRING_ACCESS_SYSTEMS      = "hiring_access_systems"
  HIRING_DISTRIBUTION_GROUPS = "hiring_distribution_groups"
  TERMINATION_REASON         = "termination_reason"

  TICKET_FORM_CATEGORIES = [
    HR_TYPES, IDEA_TYPES, WORK_TYPES, CARECLOUD_ISSUE, CUREMD_ISSUE,
    TRONSHEALTH_ISSUE, EHR_CHANGE_ISSUE
  ].freeze

  HIRING_TERMINATION_CATEGORIES = [
    HIRING_TITLE_POSITION, HIRING_DEPARTMENT, HIRING_ACCESS_SYSTEMS,
    HIRING_DISTRIBUTION_GROUPS, TERMINATION_REASON
  ].freeze

  CATEGORIES = (TICKET_FORM_CATEGORIES + HIRING_TERMINATION_CATEGORIES).freeze

  CATEGORY_LABELS = {
    HR_TYPES                   => "HR Types",
    IDEA_TYPES                 => "Bright Idea Types",
    WORK_TYPES                 => "Great Work Types",
    CARECLOUD_ISSUE            => "CareCloud Issue",
    CUREMD_ISSUE                => "CureMD Issue",
    TRONSHEALTH_ISSUE           => "TronsHealth Issue",
    EHR_CHANGE_ISSUE            => "EHR Change Issue",
    HIRING_TITLE_POSITION       => "Title / Position",
    HIRING_DEPARTMENT           => "Department",
    HIRING_ACCESS_SYSTEMS       => "Access Systems",
    HIRING_DISTRIBUTION_GROUPS  => "Distribution Groups",
    TERMINATION_REASON          => "Termination Reason"
  }.freeze

  before_validation :default_value_to_label

  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :label,    presence: true
  validates :value,    presence: true, uniqueness: { scope: :category }

  scope :active,  -> { where(is_active: true) }
  scope :ordered, -> { order(:position, :label) }

  def self.for(category)
    active.ordered.where(category: category)
  end

  private

  def default_value_to_label
    self.value = value.presence || label
  end
end
