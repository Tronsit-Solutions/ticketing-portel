require "rails_helper"

RSpec.describe ComputeSimilarTicketsJob, type: :job do
  describe "#perform" do
    it "persists the matching ids and computation metadata on the ticket" do
      ticket = create(:ticket, title: "Printer issue", metadata: { "details" => "Printer jams" })
      match_ids = [1, 2, 3]
      allow_any_instance_of(SimilarTicketFinder).to receive(:call).and_return(match_ids)

      ComputeSimilarTicketsJob.perform_now(ticket.id)
      ticket.reload

      expect(ticket.metadata["similar_ticket_ids"]).to eq(match_ids)
      expect(ticket.metadata["similar_computed_for"]).to eq("Printer issue")
      expect(ticket.metadata["similar_computed_for_description"]).to eq(ticket.display_description)
      expect(ticket.metadata["similar_rules_version"]).to eq(Ticket::SIMILAR_TICKETS_RULES_VERSION)
      expect(ticket.metadata["similar_computed_at"]).to be_present
    end

    it "does nothing when the ticket no longer exists" do
      expect(SimilarTicketFinder).not_to receive(:new)
      expect { ComputeSimilarTicketsJob.perform_now(-1) }.not_to raise_error
    end

    it "leaves metadata untouched when SimilarTicketFinder raises, so the ticket stays stale for a retry" do
      ticket = create(:ticket, title: "Printer issue", metadata: {})
      allow_any_instance_of(SimilarTicketFinder).to receive(:call).and_raise(StandardError, "boom")

      expect { ComputeSimilarTicketsJob.perform_now(ticket.id) }.not_to raise_error
      expect(ticket.reload.metadata["similar_computed_at"]).to be_nil
    end

    it "broadcasts a replace to both the agent and customer similar-tickets streams" do
      ticket = create(:ticket, title: "Printer issue", metadata: {})
      allow_any_instance_of(SimilarTicketFinder).to receive(:call).and_return([])

      broadcasts = []
      allow_any_instance_of(Ticket).to receive(:broadcast_replace_to) do |_receiver, stream, **opts|
        broadcasts << [stream, opts[:target]]
      end

      ComputeSimilarTicketsJob.perform_now(ticket.id)

      expect(broadcasts).to contain_exactly(
        [[ticket, :similar_tickets_agent],    "similar_tickets_agent_#{ticket.id}"],
        [[ticket, :similar_tickets_customer], "similar_tickets_customer_#{ticket.id}"]
      )
    end
  end
end
