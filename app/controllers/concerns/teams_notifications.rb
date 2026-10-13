# Mirrors ticket activity to the Teams channel.
# One post per event (not per receiver), sent in the background. The card
# content is snapshotted here, at the moment of the event, so a delayed job
# still describes the ticket as it was when the activity happened.
module TeamsNotifications
  extend ActiveSupport::Concern

  TEAMS_QUOTE_LIMIT = 400

  private

  def post_new_ticket_to_teams(ticket)
    summary =
      if ticket.on_behalf? && ticket.customer.present?
        "**#{current_user.fullname}** submitted a new ticket on behalf of **#{ticket.customer.fullname}**"
      else
        "**#{current_user.fullname}** submitted a new ticket"
      end

    post_to_teams(ticket, event: "created", summary: summary, quote: ticket.details, quote_label: "Description")
  end

  def post_assignment_to_teams(ticket, assignee, assigned_by:, previous: nil, reason: nil)
    event, summary =
      if previous.present? && previous != assignee
        ["reassigned", "**#{assigned_by.fullname}** reassigned this ticket from **#{previous.fullname}** to **#{assignee.fullname}**"]
      elsif assignee == assigned_by
        ["assigned", "**#{assignee.fullname}** picked up this ticket"]
      else
        ["assigned", "**#{assigned_by.fullname}** assigned this ticket to **#{assignee.fullname}**"]
      end

    post_to_teams(ticket, event: event, summary: summary, quote: reason, quote_label: "Reason")
  end

  # Internal notes are announced without their text: the note itself stays
  # inside the portal, where only staff can read it.
  def post_message_to_teams(ticket, message)
    if message.internal_note?
      post_to_teams(ticket, event: "noted", summary: "**#{current_user.fullname}** added an internal note")
    else
      post_to_teams(
        ticket,
        event:       "replied",
        summary:     "**#{current_user.fullname}** replied to this ticket",
        quote:       message.details,
        quote_label: message.message_type == "customer_reply" ? "Customer reply" : "Staff reply"
      )
    end
  end

  def post_details_to_teams(ticket, kind)
    post_to_teams(ticket, event: "details", summary: "**#{current_user.fullname}** submitted the #{kind} details")
  end

  def post_closure_to_teams(ticket)
    duration = ticket.resolution_duration
    post_to_teams(
      ticket,
      event:       "closed",
      summary:     "**#{current_user.fullname}** closed this ticket",
      quote:       ticket.resolution,
      quote_label: "Resolution",
      facts:       { "Time to resolve" => (duration unless duration.in?(%w[Pending N/A])) }
    )
  end

  def post_cancellation_to_teams(ticket)
    post_to_teams(
      ticket,
      event:   "cancelled",
      summary: "**#{current_user.fullname}** cancelled this ticket",
      facts:   { "Status" => "Cancelled" }
    )
  end

  def post_to_teams(ticket, event:, summary:, quote: nil, quote_label: nil, facts: {})
    return unless TeamsNotifier.enabled?

    TeamsNotificationJob.perform_later(
      event:       event,
      reference:   "##{ticket.id} · #{ticket.type_label}",
      subject:     ticket.title,
      summary:     summary,
      facts:       teams_ticket_facts(ticket).merge(facts),
      quote:       teams_quote(quote),
      quote_label: quote_label,
      url:         ticket_url(ticket)
    )
  end

  def teams_ticket_facts(ticket)
    {
      "Requester"   => ticket.customer&.fullname,
      "Assigned to" => ticket.assignee&.fullname || "Unassigned",
      "Location"    => ticket.location&.name,
      "Status"      => ticket.status.humanize
    }
  end

  # Replies can be rich-text HTML; Teams gets a plain-text excerpt.
  def teams_quote(text)
    return if text.blank?

    ActionView::Base.full_sanitizer.sanitize(text.to_s).squish.truncate(TEAMS_QUOTE_LIMIT).presence
  end
end
