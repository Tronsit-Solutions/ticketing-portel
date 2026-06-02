class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable


  ROLES = %w[admin agent manager customer].freeze
  validates :fullname,  presence: true
  validates :role,      inclusion: { in: ROLES }


end
