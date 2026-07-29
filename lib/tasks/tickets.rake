namespace :tickets do
  desc "Move assigned tickets stuck in 'open' status to 'in_progress'"
  task sync_assigned_status: :environment do
    tickets = Ticket.open.assigned

    puts "\n==> Found #{tickets.count} open, assigned ticket(s) to update"

    updated = tickets.update_all(status: "in_progress")

    puts "    #{updated} ticket(s) updated to 'in_progress'."
  end
end
