FactoryBot.define do
  factory :ticket_notification do
    association :ticket
    association :receiver,     factory: :user
    association :responded_by, factory: :user
    details { "You have a new notification" }
    status  { "unread" }

    trait :read   do; status { "read" };   end
    trait :unread do; status { "unread" }; end
  end
end
