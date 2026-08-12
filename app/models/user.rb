class User < ApplicationRecord
  include Auditable

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :recoverable,
         :rememberable,
         :validatable,
         :trackable


  belongs_to :team, optional: true

  has_many :assigned_tickets,  class_name: "Ticket", foreign_key: :assignee_id, dependent: :nullify
  has_many :customer_tickets,  class_name: "Ticket", foreign_key: :customer_id,  dependent: :nullify

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

  def audit_label
    fullname.presence || email
  end

  def audit_category
    AuditLog::USERS
  end

end
