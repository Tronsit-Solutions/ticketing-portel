class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :recoverable,
         :rememberable,
         :validatable,
         :trackable


  belongs_to :team, optional: true

  ROLES = %w[admin agent manager customer].freeze
  validates :fullname,  presence: true
  validates :role,      inclusion: { in: ROLES }

  def admin?;    role == "admin"    end
  def agent?;    role == "agent"    end
  def manager?;  role == "manager"  end
  def customer?; role == "customer" end

end
