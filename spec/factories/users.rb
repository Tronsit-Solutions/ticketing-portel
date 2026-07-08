FactoryBot.define do
  factory :user do
    sequence(:email)    { |n| "user#{n}@example.com" }
    fullname            { Faker::Name.name }
    password            { "password123" }
    password_confirmation { "password123" }
    role                { "customer" }
    is_active           { true }
    first_time          { false }

    trait :admin do
      role { "admin" }
      sequence(:email) { |n| "admin#{n}@example.com" }
    end

    trait :agent do
      role { "agent" }
      sequence(:email) { |n| "agent#{n}@example.com" }
    end

    trait :manager do
      role { "manager" }
      sequence(:email) { |n| "manager#{n}@example.com" }
    end

    trait :customer do
      role { "customer" }
    end

    trait :inactive do
      is_active { false }
    end
  end
end
