FactoryBot.define do
  factory :location do
    sequence(:name)         { |n| "Location #{n}" }
    sequence(:abbreviation) { |n| "L#{n}" }
    state      { "Arizona" }
    is_active  { true }
  end
end
