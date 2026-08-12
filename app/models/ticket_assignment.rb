class TicketAssignment < ApplicationRecord
  belongs_to :ticket
  belongs_to :assigned_to,   class_name: "User"
  belongs_to :assigned_from, class_name: "User", optional: true
  belongs_to :assigned_by,   class_name: "User"

  scope :recent,   -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(assigned_to: user) }

  after_create_commit :audit_assignment

  private

  def audit_assignment
    AuditLog.record!(
      actor:       Current.user || assigned_by,
      action:      AuditLog::ASSIGNED,
      category:    AuditLog::TICKETS,
      description: "#{(Current.user || assigned_by)&.fullname || 'System'} assigned ticket ##{ticket_id} to #{assigned_to.fullname}" +
                    (reason.present? ? " (#{reason})" : ""),
      auditable:    ticket,
      changed_data: {
        "assigned_to"   => assigned_to.fullname,
        "assigned_from" => assigned_from&.fullname,
        "reason"        => reason
      },
      request: Current.request
    )
  end
end
