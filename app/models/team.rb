class Team < ApplicationRecord
    has_many :users, dependent: :nullify
    validates :name, presence: true, uniqueness: true
    scope :ordered, -> { order(:name) }
end
