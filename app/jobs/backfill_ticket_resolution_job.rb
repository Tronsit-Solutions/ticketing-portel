class BackfillTicketResolutionJob < ApplicationJob
  queue_as :default

  # Legacy imports never populated Ticket#resolution — it was only ever
  # written by the (new) close-ticket form. But the last staff message on
  # an old closed ticket almost always *is* the resolution, written in
  # prose ("Issue resolved.", "Password has been reset. -Moiz", etc.)
  # rather than through that form. A handful of tickets, though, were
  # closed after nothing more than a receipt acknowledgement or a bare
  # "Escalated." with no explanation of what happened next — those carry
  # no real resolution information, so they're deliberately left blank
  # rather than backfilled with a meaningless sign-off.
  NON_RESOLUTION_PHRASES = %w[
    acknowledged
    checked
    escalated
    noted
    received
    seen
    ok
    okay
  ].freeze

  def perform(ticket_id, force: false)
    ticket = Ticket.find_by(id: ticket_id, status: "closed")
    return unless ticket
    return if ticket.resolution.present? && !force

    last_staff_message = ticket.ticket_messages
                                .joins(:sender)
                                .where(internal_note: false, users: { role: %w[agent manager admin] })
                                .order(created_at: :desc)
                                .first
    return unless last_staff_message

    candidate = resolution_candidate(last_staff_message.details)
    return unless candidate

    ticket.update_columns(
      resolution:     candidate,
      resolved_by_id: ticket.resolved_by_id || last_staff_message.sender_id,
      resolved_at:    ticket.resolved_at || last_staff_message.created_at
    )
  end

  private

  # Legacy messages are commonly signed "Issue resolved. - Jasim" or
  # "Checked. Saqib" — strip the trailing "- Name"/" Name" signature
  # before checking whether what's left is actually informative.
  def resolution_candidate(text)
    stripped = text.to_s.strip.sub(/[\s\-–—]+[A-Z][a-zA-Z]*\.?\z/, "").strip.chomp(".").strip
    return nil if stripped.blank?
    return nil if NON_RESOLUTION_PHRASES.include?(stripped.downcase)

    text.strip
  end
end
