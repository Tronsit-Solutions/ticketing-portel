class Team < ApplicationRecord
    include Auditable

    belongs_to :manager, class_name: "User", optional: true
    has_many :users, dependent: :nullify
    has_many :members, class_name: "User", foreign_key: "team_id", dependent: :nullify
    validates :name, presence: true, uniqueness: true
    scope :ordered, -> { order(:name) }

    def audit_label
      name
    end

    def audit_category
      AuditLog::TEAMS
    end
end
