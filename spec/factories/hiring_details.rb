FactoryBot.define do
  factory :hiring_detail do
    association :ticket, :hiring
    start_date      { 2.weeks.from_now.to_date }
    title_position  { "Certified Medical Assistant" }
    department      { "NYMAN" }
    gender          { "Female" }
    cell_phone      { "555-1234" }
    pc_requirement  { "They Need A New Pc" }
    microsoft_teams_department { ["Human Resources"] }

    trait :provider do
      is_provider             { true }
      billing_provider_name   { "Dr. Jane Smith" }
      provider_npi            { "1234567890" }
      q5_q6_modifier_required { false }
    end

    trait :provider_with_modifier do
      provider
      q5_q6_modifier_required { true }
      q5_q6_modifier          { "Q5" }
    end
  end
end
