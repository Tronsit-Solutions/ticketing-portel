FactoryBot.define do
  factory :ticket_message do
    association :ticket
    association :sender, factory: :user
    details      { Faker::Lorem.paragraph }
    message_type { "customer_reply" }
    internal_note { false }

    trait :agent_reply    do; message_type { "agent_reply" };    end
    trait :internal_note  do; message_type { "internal_note" }; internal_note { true }; end
  end
end
