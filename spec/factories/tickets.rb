FactoryBot.define do
  factory :ticket do
    association :customer, factory: [:user, :customer]
    title       { Faker::Lorem.sentence(word_count: 4) }
    ticket_type { "technical_support" }
    status      { "open" }
    metadata    { {} }

    trait :technical_support  do; ticket_type { "technical_support" }; end
    trait :tronshealth        do; ticket_type { "tronshealth" };       end
    trait :carecloud          do; ticket_type { "carecloud" };         end
    trait :curemd             do; ticket_type { "curemd" };            end
    trait :hr                 do; ticket_type { "hr" };                end
    trait :lms                do; ticket_type { "lms" };               end
    trait :bright_ideas do
      ticket_type { "bright_ideas" }
      title       { "Bright Idea: Improve workflow" }
    end
    trait :great_work do
      ticket_type { "great_work" }
      title       { "Great Work: Team effort" }
    end
    trait :hiring_departure do
      ticket_type { "hiring_departure" }
      title       { "New Hire: John Doe" }
    end

    trait :open        do; status { "open" };        end
    trait :in_progress do; status { "in_progress" }; end
    trait :closed      do; status { "closed" };      end
    trait :cancelled   do; status { "cancelled" };   end

    trait :assigned do
      association :assignee, factory: [:user, :agent]
      association :assigned_by, factory: [:user, :admin]
      assigned_at { Time.current }
    end

    trait :with_location do
      association :location
    end
  end
end
