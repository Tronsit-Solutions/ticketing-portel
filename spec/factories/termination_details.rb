FactoryBot.define do
  factory :termination_detail do
    association :ticket, :hiring_departure
    termination_reason { "Voluntary Resignation" }
    termination_date   { 1.week.from_now.to_date }
    termination_time   { "5:00 PM" }
    email_address      { "employee@example.com" }
  end
end
