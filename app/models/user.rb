class User < ApplicationRecord
  include Auditable

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :recoverable,
         :rememberable,
         :validatable,
         :trackable,
         :lockable,
         :timeoutable


  belongs_to :team, optional: true

  has_many :assigned_tickets,  class_name: "Ticket", foreign_key: :assignee_id, dependent: :nullify
  has_many :customer_tickets,  class_name: "Ticket", foreign_key: :customer_id,  dependent: :nullify

  TEMPORARY_PASSWORD_LENGTH = 12

  # Replaces the password with a random one-time password the user must
  # change at their next sign-in, and lifts any failed-login lock. Returns
  # the new password so the staff member who reset it can pass it on; it is
  # not stored anywhere else.
  def reset_to_temporary_password!
    temporary = SecureRandom.alphanumeric(TEMPORARY_PASSWORD_LENGTH)
    update!(password: temporary, password_confirmation: temporary, must_change_password: true,
            failed_attempts: 0, locked_at: nil)
    temporary
  end

  ROLES = %w[admin agent manager customer].freeze
  # validates :fullname,  presence: true
  validates :role,      inclusion: { in: ROLES }

  scope :agents,    -> { where(role: "agent") }
  scope :customers, -> { where(role: "customer") }
  scope :active,    -> { where(is_active: true) }

  def admin?;    role == "admin"    end
  def agent?;    role == "agent"    end
  def manager?;  role == "manager"  end
  def customer?; role == "customer" end

  def active_for_authentication?
    super && is_active?
  end

  def inactive_message
    is_active? ? super : :deactivated
  end

  # Paranoid mode makes every failed sign-in say "Invalid email or password",
  # including for a locked account. Tell locked users the real reason so the
  # sign-in page can show when they may try again.
  def unauthenticated_message
    access_locked? ? :locked : super
  end

  # When a locked account becomes usable again, or nil if it isn't locked.
  def unlocks_at
    locked_at + self.class.unlock_in if access_locked?
  end

  def ticket_stats
    {
      open:   assigned_tickets.open.count + assigned_tickets.in_progress.count,
      closed: assigned_tickets.closed.count,
      total:  assigned_tickets.count
    }
  end

  def audit_label
    fullname.presence || email
  end

  def audit_category
    AuditLog::USERS
  end

end
