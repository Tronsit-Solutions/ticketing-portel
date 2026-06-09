# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end


puts "Cleaning database..."
TicketNotification.destroy_all
# TicketFile.destroy_all
TicketMessage.destroy_all
TicketAssignment.destroy_all
Ticket.destroy_all
User.destroy_all
Team.destroy_all
Location.destroy_all

puts "Seeding locations..."
locations = [
  { name: "Main Office",    abbreviation: "MO", state: "California" },
  { name: "North Branch",   abbreviation: "NB", state: "New York"   },
  { name: "South Branch",   abbreviation: "SB", state: "Texas"      },
  { name: "West Branch",    abbreviation: "WB", state: "Washington" },
]
locations.each { |l| Location.create!(l) }

puts "Seeding teams..."
teams = [
  { name: "Technical Support" },
  { name: "HR Support"        },
  { name: "CareCloud Support" },
]
teams.each { |t| Team.create!(t) }

tech_team = Team.find_by(name: "Technical Support")
hr_team   = Team.find_by(name: "HR Support")

puts "Seeding users..."

# Admin
admin = User.create!(
  fullname:   "Admin User",
  email:      "admin@portal.com",
  password:   "password123",
  role:       "admin",
  contact_no: "09000000001",
  address:    "Main Office",
  is_active:  true,
  first_time: false
)

# Agents
agent1 = User.create!(
  fullname:   "Alice Santos",
  email:      "agent1@portal.com",
  password:   "password123",
  role:       "agent",
  contact_no: "09000000002",
  address:    "Main Office",
  team:       tech_team,
  is_active:  true,
  first_time: false
)

agent2 = User.create!(
  fullname:   "Bob Reyes",
  email:      "agent2@portal.com",
  password:   "password123",
  role:       "agent",
  contact_no: "09000000003",
  address:    "North Branch",
  team:       hr_team,
  is_active:  true,
  first_time: false
)

# Manager
manager = User.create!(
  fullname:   "Carol Mendoza",
  email:      "manager@portal.com",
  password:   "password123",
  role:       "manager",
  contact_no: "09000000004",
  address:    "Main Office",
  team:       tech_team,
  is_active:  true,
  first_time: false
)

# Customers
customer1 = User.create!(
  fullname:   "Dan Cruz",
  email:      "customer1@portal.com",
  password:   "password123",
  role:       "customer",
  contact_no: "09000000005",
  address:    "South Branch",
  is_active:  true,
  first_time: true
)

customer2 = User.create!(
  fullname:   "Eva Lim",
  email:      "customer2@portal.com",
  password:   "password123",
  role:       "customer",
  contact_no: "09000000006",
  address:    "West Branch",
  is_active:  true,
  first_time: true
)

customer3 = User.create!(
  fullname:   "Frank Torres",
  email:      "customer3@portal.com",
  password:   "password123",
  role:       "customer",
  contact_no: "09000000007",
  address:    "North Branch",
  is_active:  true,
  first_time: true
)

puts "Seeding tickets..."

main_office  = Location.find_by(name: "Main Office")
north_branch = Location.find_by(name: "North Branch")
south_branch = Location.find_by(name: "South Branch")
west_branch  = Location.find_by(name: "West Branch")

tickets_data = [
  {
    title:       "Cannot access EHR system",
    ticket_type: "technical_support",
    status:      "in_progress",
    location:    main_office,
    customer:    customer1,
    assignee:    agent1,
    assigned_by: admin,
    assigned_at: 2.days.ago
  },
  {
    title:       "Printer not working at North Branch",
    ticket_type: "technical_support",
    status:      "open",
    location:    north_branch,
    customer:    customer2,
    assignee:    nil,
    assigned_by: nil
  },
  {
    title:       "Update employee address",
    ticket_type: "hr",
    status:      "closed",
    location:    south_branch,
    customer:    customer3,
    assignee:    agent2,
    assigned_by: admin,
    assigned_at: 5.days.ago,
    resolved_at: 3.days.ago,
    resolved_by: agent2
  },
  {
    title:       "VPN connection dropping every 15 minutes",
    ticket_type: "technical_support",
    status:      "open",
    location:    west_branch,
    customer:    customer1,
    assignee:    nil,
    assigned_by: nil
  },
  {
    title:       "Suggestion: add dark mode to portal",
    ticket_type: "bright_ideas",
    status:      "open",
    location:    main_office,
    customer:    customer2,
    assignee:    nil,
    assigned_by: nil
  },
  {
    title:       "CareCloud login failure",
    ticket_type: "carecloud",
    status:      "closed",
    location:    main_office,
    customer:    customer1,
    assignee:    agent1,
    assigned_by: admin,
    assigned_at: 7.days.ago,
    resolved_at: 6.days.ago,
    resolved_by: agent1
  },
  {
    title:       "New team member onboarding",
    ticket_type: "hiring",
    status:      "in_progress",
    location:    north_branch,
    customer:    customer3,
    assignee:    agent2,
    assigned_by: manager,
    assigned_at: 1.day.ago
  },
]

tickets_data.each { |t| Ticket.create!(t) }

puts "Seeding ticket assignments..."

Ticket.where.not(assignee_id: nil).each do |ticket|
  TicketAssignment.create!(
    ticket:        ticket,
    assigned_to:   ticket.assignee,
    assigned_from: nil,
    assigned_by:   ticket.assigned_by || admin,
    reason:        "Initial assignment"
  )
end

# One reassignment example
first_ticket = Ticket.find_by(title: "Cannot access EHR system")
TicketAssignment.create!(
  ticket:        first_ticket,
  assigned_to:   agent2,
  assigned_from: agent1,
  assigned_by:   admin,
  reason:        "Agent1 unavailable, reassigned to Agent2"
)

puts "Seeding ticket details..."

thread_data = [
  {
    ticket:       Ticket.find_by(title: "Cannot access EHR system"),
    messages: [
      { sender: customer1, type: "customer_reply", body: "I cannot log into the EHR system since this morning. Error says Invalid credentials." },
      { sender: agent1,    type: "agent_reply",    body: "We have reset your credentials. Please try logging in again." },
      { sender: customer1, type: "customer_reply", body: "Still getting the same error." },
      { sender: agent1,    type: "internal_note",  body: "Escalating to IT admin. Possible account lock." },
    ]
  },
  {
    ticket:   Ticket.find_by(title: "CareCloud login failure"),
    messages: [
      { sender: customer1, type: "customer_reply", body: "CareCloud is not accepting my password even after reset." },
      { sender: agent1,    type: "agent_reply",    body: "Issue resolved after clearing browser cache. Please try again." },
      { sender: customer1, type: "customer_reply", body: "Working now, thank you!" },
    ]
  },
  {
    ticket:   Ticket.find_by(title: "Update employee address"),
    messages: [
      { sender: customer3, type: "customer_reply", body: "I recently moved and need to update my address in employee records." },
      { sender: agent2,    type: "agent_reply",    body: "Address has been updated. Please verify at your next login." },
    ]
  },
]

thread_data.each do |thread|
  thread[:messages].each_with_index do |msg, i|
    TicketMessage.create!(
      ticket:       thread[:ticket],
      sender:       msg[:sender],
      details:      msg[:body],
      message_type: msg[:type],
      created_at:   (thread[:messages].length - i).days.ago
    )
  end
end

puts "Seeding ticket notifications..."

Ticket.all.each do |ticket|
  next unless ticket.customer.present?
  TicketNotification.create!(
    ticket:       ticket,
    responded_by: ticket.assignee || admin,
    receiver:     ticket.customer,
    details:      "Your ticket '#{ticket.title}' has been updated.",
    status:       "unread"
  )
end

puts ""
puts "Seed complete!"
puts "──────────────────────────────────────"
puts "Login credentials:"
puts "  admin@portal.com    / password123  (admin)"
puts "  agent1@portal.com   / password123  (agent)"
puts "  agent2@portal.com   / password123  (agent)"
puts "  manager@portal.com  / password123  (manager)"
puts "  customer1@portal.com / password123 (customer)"
puts "  customer2@portal.com / password123 (customer)"
puts "  customer3@portal.com / password123 (customer)"
puts "──────────────────────────────────────"
