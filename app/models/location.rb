class Location < ApplicationRecord
  has_many :tickets, dependent: :nullify

  validates :name,         presence: true, uniqueness: true
  validates :abbreviation, presence: true
  validates :state,        presence: true

  scope :active,   -> { where(is_active: true) }
  scope :ordered,  -> { order(:name) }
end
