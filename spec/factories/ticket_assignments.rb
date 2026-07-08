FactoryBot.define do
  factory :ticket_assignment do
    association :ticket
    association :assigned_to,  factory: [:user, :agent]
    association :assigned_by,  factory: [:user, :admin]
    reason { "Assigning to relevant agent" }
  end
end
