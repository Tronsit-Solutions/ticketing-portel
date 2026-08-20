class DropdownOption < ApplicationRecord
  include Auditable

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
  validates :label,    presence: true, uniqueness: { scope: :category, case_sensitive: false }
  validates :value,    presence: true, uniqueness: { scope: :category }

  before_create :assign_position

  after_create  :shift_later_positions
  after_update  :move_within_active_siblings, if: :moved_while_staying_active?
  after_update  :close_position_gap,          if: :becoming_inactive?
  # Re-enabling reinserts the item at its stored position, pushing whatever
  # is currently sitting there (and beyond) back down one slot.
  after_update  :shift_later_positions,       if: :becoming_active?

  scope :active,  -> { where(is_active: true) }
  scope :ordered, -> { order(:position, :label) }

  def self.for(category)
    active.ordered.where(category: category)
  end

  def audit_label
    "#{CATEGORY_LABELS[category] || category}: #{label}"
  end

  def audit_category
    AuditLog::SETTINGS
  end

  private

  def audit_create_snapshot
    { "id" => id, "label" => label }
  end

  def default_value_to_label
    self.value = value.presence || label
  end

  # New options default to the end of the (active) list unless a specific position was requested.
  def assign_position
    return if position.present?

    max_position = DropdownOption.where(category: category).maximum(:position) || 0
    self.position = max_position + 1
  end

  # Inserting a brand-new option, or reinserting a re-enabled one, pushes
  # whatever is sitting at that slot (and everything after it) forward one
  # slot, so positions stay contiguous and unambiguous.
  def shift_later_positions
    DropdownOption.active.where(category: category)
                  .where.not(id: id)
                  .where("position >= ?", position)
                  .order(position: :asc)
                  .each { |sibling| sibling.update_column(:position, sibling.position + 1) }
  end

  # Moving an already-active option to a new slot displaces only the options
  # between its old and new position, sliding them back the other direction
  # to close the gap left behind and make room at the destination.
  def move_within_active_siblings
    old_position = saved_change_to_position.first
    new_position = position

    siblings = DropdownOption.active.where(category: category).where.not(id: id)

    if new_position > old_position
      siblings.where(position: (old_position + 1)..new_position)
              .each { |sibling| sibling.update_column(:position, sibling.position - 1) }
    else
      siblings.where(position: new_position...old_position)
              .each { |sibling| sibling.update_column(:position, sibling.position + 1) }
    end
  end

  # Disabling an item removes it from the active ordering, so later active
  # items shift up one slot to close the gap it leaves behind. The item keeps
  # its own position value so it can be reinserted in the same spot later.
  def close_position_gap
    DropdownOption.active.where(category: category)
                  .where("position > ?", position)
                  .order(position: :asc)
                  .each { |sibling| sibling.update_column(:position, sibling.position - 1) }
  end

  def becoming_inactive?
    saved_change_to_is_active? && !is_active?
  end

  def becoming_active?
    saved_change_to_is_active? && is_active?
  end

  def moved_while_staying_active?
    saved_change_to_position? && is_active? && !saved_change_to_is_active?
  end
end
