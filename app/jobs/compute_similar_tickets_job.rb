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
        "similar_computed_for"  => ticket.title
      )
    )
    broadcast_similar(ticket)

    # Similarity should read the same from either side: if A finds B similar,
    # B's page should show A too, without waiting on B's own recompute cycle.
    Ticket.where(id: ids).find_each do |matched|
      next if matched.metadata["similar_ticket_ids"].to_a.include?(ticket.id)

      matched.update_columns(
        metadata: matched.metadata.merge(
          "similar_ticket_ids" => (matched.metadata["similar_ticket_ids"].to_a + [ticket.id]).uniq
        )
      )
      broadcast_similar(matched)
    end
  end

  private

  def broadcast_similar(ticket)
    similar = ticket.similar_tickets

    %i[agent customer].each do |variant|
      ticket.broadcast_replace_to [ticket, :"similar_tickets_#{variant}"],
        target:  "similar_tickets_#{variant}_#{ticket.id}",
        partial: "tickets/similar_tickets",
        locals:  { ticket: ticket, similar_tickets: similar, variant: variant }
    end
  end
end
