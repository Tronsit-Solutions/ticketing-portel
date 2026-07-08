FactoryBot.define do
  factory :hiring_detail do
    association :ticket, :hiring_departure
    start_date      { 2.weeks.from_now.to_date }
    title_position  { "Medical Assistant" }
    department      { "Clinical" }
    gender          { "Female" }
    cell_phone      { "555-1234" }
    pc_requirement  { "They Need A New Pc" }
  end
end
