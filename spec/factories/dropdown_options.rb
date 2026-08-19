FactoryBot.define do
  factory :dropdown_option do
    category { DropdownOption::HR_TYPES }
    sequence(:label) { |n| "Option #{n}" }
  end
end
