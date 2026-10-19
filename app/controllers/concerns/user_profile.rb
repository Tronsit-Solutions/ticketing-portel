# Loads what the shared user profile page (shared/_user_profile) shows, for
# the admin, manager and agent portals alike.
module UserProfile
  extend ActiveSupport::Concern

  PROFILE_TICKET_SORT_COLUMNS = {
    "id" => "tickets.id", "title" => "tickets.title", "status" => "tickets.status", "person" => "users.fullname"
  }.freeze

  private

  def load_user_profile(user)
    @recent_activity = AuditLog.by_actor(user.id).recent.limit(6)

    # Agents and managers are shown the tickets assigned to them, customers the
    # tickets they raised; the "person" column is whoever is on the other side.
    if user.agent? || user.manager?
      tickets, @person_association = user.assigned_tickets, :customer
    elsif user.customer?
      tickets, @person_association = user.customer_tickets, :assignee
    else
      return
    end

    @status_counts = tickets.group(:status).count
    @type_counts   = tickets.group(:ticket_type).count.sort_by { |_, count| -count }
    @total_count   = @status_counts.values.sum

    @tickets = tickets.includes(@person_association, :location)
    @tickets = @tickets.where(status: params[:status]) if Ticket::STATUSES.include?(params[:status])

    @ticket_sort      = PROFILE_TICKET_SORT_COLUMNS.key?(params[:ticket_sort]) ? params[:ticket_sort] : nil
    @ticket_direction = params[:ticket_direction] == "desc" ? "desc" : "asc"
    if @ticket_sort
      @tickets = @tickets.left_joins(@person_association).order(PROFILE_TICKET_SORT_COLUMNS[@ticket_sort] => @ticket_direction)
    else
      @tickets = @tickets.recent
    end
    @tickets = @tickets.page(params[:page]).per(8)
  end
end
