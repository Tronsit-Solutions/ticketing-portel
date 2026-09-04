require "rails_helper"

RSpec.describe SimilarTicketFinder do
  # Embeddings are stubbed with explicit vectors instead of exercising the
  # real ONNX model, so each test controls similarity precisely:
  # identical vectors => cosine similarity 1.0 (match), orthogonal unit
  # vectors => 0.0 (no match), near-identical vectors => just above/below
  # SimilarTicketFinder::SIMILARITY_THRESHOLD (0.6).
  MATCHING      = [1.0, 0.0, 0.0].freeze
  ALSO_MATCHING = [0.9, 0.1, 0.0].freeze # cosine sim vs MATCHING ~0.994 => matches
  UNRELATED     = [0.0, 1.0, 0.0].freeze # cosine sim vs MATCHING = 0.0
  OTHER_AXIS    = [0.0, 0.0, 1.0].freeze # cosine sim vs MATCHING = 0.0

  def stub_embedding(text, vector)
    allow(TicketEmbedder).to receive(:embed).with(text).and_return(vector)
  end

  let(:customer) { create(:user, :customer) }

  def closed_ticket(title:, ticket_type: "technical_support", resolution: "Fixed it", metadata: {})
    create(:ticket, ticket_type: ticket_type, status: "closed", title: title,
                     resolution: resolution, metadata: metadata, customer: customer)
  end

  describe "#call" do
    context "when titles are similar" do
      it "matches candidates whose title embedding is within the similarity threshold" do
        target = create(:ticket, ticket_type: "technical_support", title: "Printer will not print")
        match  = closed_ticket(title: "Unable to print documents")

        stub_embedding(target.title, MATCHING)
        stub_embedding(match.title, ALSO_MATCHING)

        expect(SimilarTicketFinder.new(target).call).to eq([match.id])
      end

      it "does not match candidates whose title embedding is below the threshold" do
        target  = create(:ticket, ticket_type: "technical_support", title: "Printer will not print")
        unrelated = closed_ticket(title: "Cannot access email")

        stub_embedding(target.title, MATCHING)
        stub_embedding(unrelated.title, UNRELATED)

        expect(SimilarTicketFinder.new(target).call).to eq([])
      end

      it "does not fall back to description when the title already matches" do
        target = create(:ticket, ticket_type: "technical_support", title: "Printer will not print",
                                  metadata: { "details" => "ink issue" })
        match  = closed_ticket(title: "Unable to print documents", metadata: { "details" => "completely different topic" })

        stub_embedding(target.title, MATCHING)
        stub_embedding(match.title, ALSO_MATCHING)
        # No stub for descriptions — if the code tried to embed them, this
        # would raise (verifying instance doubles disallow unstubbed calls
        # only when allow().with() doesn't match); assert explicitly instead.
        allow(TicketEmbedder).to receive(:embed).with("ink issue").and_raise("should not embed target description")
        allow(TicketEmbedder).to receive(:embed).with("completely different topic").and_raise("should not embed candidate description")

        expect(SimilarTicketFinder.new(target).call).to eq([match.id])
      end
    end

    context "when titles are not similar but descriptions are" do
      it "falls back to description similarity and matches" do
        target = create(:ticket, ticket_type: "technical_support", title: "Issue A",
                                  metadata: { "details" => "The office printer jams on every print job" })
        match  = closed_ticket(title: "Issue B", metadata: { "details" => "Printer keeps jamming when printing" })

        stub_embedding(target.title, MATCHING)
        stub_embedding(match.title, UNRELATED)
        stub_embedding(target.display_description, MATCHING)
        stub_embedding(match.display_description, ALSO_MATCHING)

        expect(SimilarTicketFinder.new(target).call).to eq([match.id])
      end

      it "does not match when neither title nor description are similar" do
        target = create(:ticket, ticket_type: "technical_support", title: "Issue A",
                                  metadata: { "details" => "Printer jams constantly" })
        other  = closed_ticket(title: "Issue B", metadata: { "details" => "Cannot log into the VPN" })

        stub_embedding(target.title, MATCHING)
        stub_embedding(other.title, UNRELATED)
        stub_embedding(target.display_description, MATCHING)
        stub_embedding(other.display_description, OTHER_AXIS)

        expect(SimilarTicketFinder.new(target).call).to eq([])
      end
    end

    context "when the target has no description" do
      it "does not attempt description fallback and simply excludes non-title matches" do
        target = create(:ticket, ticket_type: "technical_support", title: "Issue A", metadata: {})
        other  = closed_ticket(title: "Issue B", metadata: { "details" => "Some description text" })

        stub_embedding(target.title, MATCHING)
        stub_embedding(other.title, UNRELATED)
        expect(target.display_description).to be_nil

        expect(SimilarTicketFinder.new(target).call).to eq([])
      end
    end

    context "when the target has a description but the candidate has none" do
      it "does not match on description for that candidate" do
        target = create(:ticket, ticket_type: "technical_support", title: "Issue A",
                                  metadata: { "details" => "Printer jams constantly" })
        other  = closed_ticket(title: "Issue B", metadata: {})

        stub_embedding(target.title, MATCHING)
        stub_embedding(other.title, UNRELATED)
        stub_embedding(target.display_description, MATCHING)
        expect(other.display_description).to be_nil

        expect(SimilarTicketFinder.new(target).call).to eq([])
      end
    end

    context "category scoping" do
      it "excludes candidates from a different ticket_type even with an identical title" do
        target = create(:ticket, ticket_type: "technical_support", title: "Same title")
        other_category = closed_ticket(title: "Same title", ticket_type: "carecloud")

        stub_embedding(target.title, MATCHING)
        stub_embedding(other_category.title, MATCHING)

        expect(SimilarTicketFinder.new(target).call).to eq([])
      end
    end

    context "candidate eligibility" do
      it "excludes tickets that are not closed" do
        target = create(:ticket, ticket_type: "technical_support", title: "Printer issue")
        open_ticket = create(:ticket, ticket_type: "technical_support", status: "open",
                                       title: "Printer issue too", resolution: "Fixed it")

        stub_embedding(target.title, MATCHING)
        stub_embedding(open_ticket.title, MATCHING)

        expect(SimilarTicketFinder.new(target).call).to eq([])
      end

      it "excludes closed tickets with a blank resolution" do
        target = create(:ticket, ticket_type: "technical_support", title: "Printer issue")
        no_resolution = create(:ticket, ticket_type: "technical_support", status: "closed",
                                         title: "Printer issue too", resolution: "")

        stub_embedding(target.title, MATCHING)
        stub_embedding(no_resolution.title, MATCHING)

        expect(SimilarTicketFinder.new(target).call).to eq([])
      end

      it "excludes closed tickets with a nil resolution" do
        target = create(:ticket, ticket_type: "technical_support", title: "Printer issue")
        no_resolution = create(:ticket, ticket_type: "technical_support", status: "closed",
                                         title: "Printer issue too", resolution: nil)

        stub_embedding(target.title, MATCHING)
        stub_embedding(no_resolution.title, MATCHING)

        expect(SimilarTicketFinder.new(target).call).to eq([])
      end

      it "excludes the ticket itself from its own candidate set" do
        target = closed_ticket(title: "Printer issue")
        stub_embedding(target.title, MATCHING)

        expect(SimilarTicketFinder.new(target).call).to eq([])
      end
    end

    context "when there are no candidates at all" do
      it "returns an empty array without computing the target embedding" do
        target = create(:ticket, ticket_type: "technical_support", title: "Printer issue")

        expect(TicketEmbedder).not_to receive(:embed)
        expect(SimilarTicketFinder.new(target).call).to eq([])
      end
    end

    context "embedding caching" do
      it "persists the computed title embedding on the candidate and reuses it on a later call" do
        target = create(:ticket, ticket_type: "technical_support", title: "Printer issue")
        match  = closed_ticket(title: "Printer issue too")

        stub_embedding(target.title, MATCHING).once
        stub_embedding(match.title, ALSO_MATCHING).once

        SimilarTicketFinder.new(target).call
        match.reload
        expect(match.metadata["title_embedding"]).to eq(ALSO_MATCHING)
        expect(match.metadata["title_embedding_for"]).to eq(match.title)

        # Second run should not need to recompute the candidate's title embedding.
        allow(TicketEmbedder).to receive(:embed).with(match.title).and_raise("should reuse cached embedding")
        stub_embedding(target.title, MATCHING)
        expect(SimilarTicketFinder.new(target).call).to eq([match.id])
      end

      it "recomputes the cached title embedding when the candidate's title has since changed" do
        target = create(:ticket, ticket_type: "technical_support", title: "Printer issue")
        match  = closed_ticket(title: "Old title", metadata: {
          "title_embedding" => OTHER_AXIS, "title_embedding_for" => "Old title"
        })
        match.update_columns(title: "Printer issue too")

        stub_embedding(target.title, MATCHING)
        stub_embedding(match.title, ALSO_MATCHING)

        expect(SimilarTicketFinder.new(target).call).to eq([match.id])
        expect(match.reload.metadata["title_embedding"]).to eq(ALSO_MATCHING)
      end

      it "persists the computed description embedding on the candidate and reuses it on a later call" do
        target = create(:ticket, ticket_type: "technical_support", title: "Issue A",
                                  metadata: { "details" => "Printer jams constantly" })
        match  = closed_ticket(title: "Issue B", metadata: { "details" => "The printer jams a lot" })

        stub_embedding(target.title, MATCHING)
        stub_embedding(match.title, UNRELATED)
        stub_embedding(target.display_description, MATCHING)
        stub_embedding(match.display_description, ALSO_MATCHING).once

        SimilarTicketFinder.new(target).call
        match.reload
        expect(match.metadata["description_embedding"]).to eq(ALSO_MATCHING)
        expect(match.metadata["description_embedding_for"]).to eq(match.display_description)
      end

      it "recomputes the cached description embedding when the candidate's description has since changed" do
        target = create(:ticket, ticket_type: "technical_support", title: "Issue A",
                                  metadata: { "details" => "Printer jams constantly" })
        match  = closed_ticket(title: "Issue B", metadata: {
          "details" => "The printer jams a lot",
          "description_embedding" => OTHER_AXIS,
          "description_embedding_for" => "stale description"
        })

        stub_embedding(target.title, MATCHING)
        stub_embedding(match.title, UNRELATED)
        stub_embedding(target.display_description, MATCHING)
        stub_embedding(match.display_description, ALSO_MATCHING)

        expect(SimilarTicketFinder.new(target).call).to eq([match.id])
      end
    end

    context "candidate volume" do
      it "limits to CANDIDATE_LIMIT most recent candidates" do
        stub_const("SimilarTicketFinder::CANDIDATE_LIMIT", 2)
        target = create(:ticket, ticket_type: "technical_support", title: "Printer issue")

        old1 = closed_ticket(title: "Printer issue A")
        old1.update_columns(created_at: 3.days.ago)
        old2 = closed_ticket(title: "Printer issue B")
        old2.update_columns(created_at: 2.days.ago)
        recent = closed_ticket(title: "Printer issue C")
        recent.update_columns(created_at: 1.day.ago)

        stub_embedding(target.title, MATCHING)
        stub_embedding(old2.title, MATCHING)
        stub_embedding(recent.title, MATCHING)
        allow(TicketEmbedder).to receive(:embed).with(old1.title).and_raise("should not consider oldest candidate beyond limit")

        result = SimilarTicketFinder.new(target).call
        expect(result).to contain_exactly(old2.id, recent.id)
      end
    end
  end
end
