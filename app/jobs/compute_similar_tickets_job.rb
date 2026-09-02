class ComputeSimilarTicketsJob < ApplicationJob
  queue_as :default

  def perform(ticket_id)
    ticket = Ticket.find_by(id: ticket_id)
    return unless ticket

    begin
      ids = SimilarTicketFinder.new(ticket).call
    rescue StandardError => e
      # Leave metadata untouched so the ticket stays "stale" and gets
      # retried on the next visit, instead of caching a false "no matches".
      Rails.logger.error("[ComputeSimilarTicketsJob] failed for ticket ##{ticket.id}: #{e.class} #{e.message}")
      return
    end

    ticket.update_columns(
      metadata: ticket.metadata.merge(
        "similar_ticket_ids"    => ids,
        "similar_computed_at"   => Time.current.iso8601,
        "similar_computed_for"  => ticket.title,
        "similar_rules_version" => Ticket::SIMILAR_TICKETS_RULES_VERSION
      )
    )
    broadcast_similar(ticket)
  end

  private

  def broadcast_similar(ticket)
    # Always broadcasts page 1 — a fresh compute means whatever page anyone
    # else was on is no longer meaningful, and re-rendering the page they
    # happened to be viewing would require tracking per-viewer state this
    # job has no way to know about.
    similar = ticket.similar_tickets.page(1).per(4)

    %i[agent customer].each do |variant|
      ticket.broadcast_replace_to [ticket, :"similar_tickets_#{variant}"],
        target:  "similar_tickets_#{variant}_#{ticket.id}",
        partial: "tickets/similar_tickets",
        locals:  { ticket: ticket, similar_tickets: similar, variant: variant }
    end
  end
end
