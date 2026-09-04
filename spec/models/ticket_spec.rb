require "rails_helper"

RSpec.describe Ticket, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:location).optional }
    it { is_expected.to belong_to(:customer).optional }
    it { is_expected.to belong_to(:assignee).optional }
    it { is_expected.to belong_to(:assigned_by).optional }
    it { is_expected.to belong_to(:resolved_by).optional }
    it { is_expected.to belong_to(:created_by).optional }
    it { is_expected.to have_many(:ticket_assignments).dependent(:destroy) }
    it { is_expected.to have_many(:ticket_messages).dependent(:destroy) }
    it { is_expected.to have_many(:ticket_notifications).dependent(:destroy) }
    it { is_expected.to have_one(:hiring_detail).dependent(:destroy) }
    it { is_expected.to have_one(:termination_detail).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_inclusion_of(:ticket_type).in_array(Ticket::TICKET_TYPES) }
    it { is_expected.to validate_inclusion_of(:status).in_array(Ticket::STATUSES) }

    it "is valid with valid attributes" do
      expect(build(:ticket)).to be_valid
    end

    it "is invalid without a title" do
      expect(build(:ticket, title: nil)).not_to be_valid
    end

    it "is invalid with an unknown ticket_type" do
      expect(build(:ticket, ticket_type: "unknown_type")).not_to be_valid
    end

    it "is invalid with an unknown status" do
      expect(build(:ticket, status: "pending")).not_to be_valid
    end
  end

  describe "scopes" do
    let!(:open_ticket)        { create(:ticket, :open) }
    let!(:in_progress_ticket) { create(:ticket, :in_progress) }
    let!(:closed_ticket)      { create(:ticket, :closed) }
    let!(:cancelled_ticket)   { create(:ticket, :cancelled) }
    let!(:assigned_ticket)    { create(:ticket, :assigned) }
    let!(:unassigned_ticket)  { create(:ticket) }

    it ".open returns open tickets" do
      expect(Ticket.open).to include(open_ticket)
      expect(Ticket.open).not_to include(closed_ticket)
    end

    it ".in_progress returns in_progress tickets" do
      expect(Ticket.in_progress).to include(in_progress_ticket)
    end

    it ".closed returns closed tickets" do
      expect(Ticket.closed).to include(closed_ticket)
    end

    it ".cancelled returns cancelled tickets" do
      expect(Ticket.cancelled).to include(cancelled_ticket)
    end

    it ".assigned returns tickets with an assignee" do
      expect(Ticket.assigned).to include(assigned_ticket)
      expect(Ticket.assigned).not_to include(unassigned_ticket)
    end

    it ".unassigned returns tickets without an assignee" do
      expect(Ticket.unassigned).to include(unassigned_ticket)
      expect(Ticket.unassigned).not_to include(assigned_ticket)
    end

    it ".recent orders by created_at descending" do
      tickets = Ticket.recent.to_a
      expect(tickets).to eq(tickets.sort_by(&:created_at).reverse)
    end
  end

  describe "callbacks" do
    describe "#auto_title_for_bright_ideas" do
      it "auto-generates title for bright_ideas if blank" do
        ticket = build(:ticket, ticket_type: "bright_ideas", title: "", metadata: { "idea_types" => ["Workflow"] })
        ticket.valid?
        expect(ticket.title).to eq("Bright Ideas")
      end

      it "auto-generates title for great_work if blank" do
        ticket = build(:ticket, ticket_type: "great_work", title: "", metadata: { "work_types" => ["Teamwork"] })
        ticket.valid?
        expect(ticket.title).to eq("Great Work")
      end

      it "auto-generates title for lms if blank" do
        ticket = build(:ticket, ticket_type: "lms", title: "")
        ticket.valid?
        expect(ticket.title).to eq("LMS")
      end

      it "auto-generates title for hiring if blank" do
        ticket = build(:ticket, ticket_type: "hiring", title: "")
        ticket.valid?
        expect(ticket.title).to eq("Hiring")
      end

      it "auto-generates title for departure if blank" do
        ticket = build(:ticket, ticket_type: "departure", title: "")
        ticket.valid?
        expect(ticket.title).to eq("Departure")
      end

      it "does not overwrite an existing title" do
        ticket = build(:ticket, ticket_type: "lms", title: "Custom Title")
        ticket.valid?
        expect(ticket.title).to eq("Custom Title")
      end
    end

    describe "#set_resolved_at" do
      it "sets resolved_at when status changes to closed" do
        ticket = create(:ticket, :open)
        expect { ticket.update!(status: "closed") }.to change { ticket.resolved_at }.from(nil)
      end

      it "sets resolved_at when status changes to cancelled" do
        ticket = create(:ticket, :open)
        expect { ticket.update!(status: "cancelled") }.to change { ticket.resolved_at }.from(nil)
      end

      it "does not set resolved_at when closing to in_progress" do
        ticket = create(:ticket, :open)
        ticket.update!(status: "in_progress")
        expect(ticket.resolved_at).to be_nil
      end
    end
  end

  describe "#on_behalf?" do
    it "returns true when created_by is present" do
      admin = create(:user, :admin)
      ticket = create(:ticket, created_by: admin)
      expect(ticket.on_behalf?).to be true
    end

    it "returns false when created_by is nil" do
      ticket = create(:ticket)
      expect(ticket.on_behalf?).to be false
    end
  end

  describe "#details accessor" do
    it "reads and writes details from metadata" do
      ticket = build(:ticket, metadata: {})
      ticket.details = "Some details"
      expect(ticket.details).to eq("Some details")
    end
  end

  describe "#display_description" do
    it "prefers metadata details when present" do
      ticket = build(:ticket, metadata: { "details" => "Details text", "description" => "Description text" })
      expect(ticket.display_description).to eq("Details text")
    end

    it "falls back to metadata description when details is blank" do
      ticket = build(:ticket, metadata: { "details" => "", "description" => "Description text" })
      expect(ticket.display_description).to eq("Description text")
    end

    it "falls back to the first customer reply when no metadata description exists" do
      ticket = create(:ticket, metadata: {})
      create(:ticket_message, ticket: ticket, sender: ticket.customer, details: "My printer is broken")

      expect(ticket.display_description).to eq("My printer is broken")
    end

    it "returns nil when there is no metadata description and no customer message" do
      ticket = create(:ticket, metadata: {})
      expect(ticket.display_description).to be_nil
    end

    it "ignores internal notes and agent replies when falling back to the first customer message" do
      ticket = create(:ticket, metadata: {})
      create(:ticket_message, :agent_reply, ticket: ticket, details: "Internal update")
      create(:ticket_message, :internal_note, ticket: ticket, sender: ticket.customer, details: "Note to self")

      expect(ticket.display_description).to be_nil
    end
  end

  describe "similar tickets" do
    describe "#similar_tickets" do
      it "returns an empty relation when no ids are cached" do
        ticket = create(:ticket, metadata: {})
        expect(ticket.similar_tickets).to eq(Ticket.none)
      end

      it "returns tickets for the cached ids, most recent first" do
        older = create(:ticket, created_at: 2.days.ago)
        newer = create(:ticket, created_at: 1.day.ago)
        ticket = create(:ticket, metadata: { "similar_ticket_ids" => [older.id, newer.id] })

        expect(ticket.similar_tickets.to_a).to eq([newer, older])
      end
    end

    describe "#similar_tickets_computed?" do
      it "is false when never computed" do
        expect(build(:ticket, metadata: {}).similar_tickets_computed?).to be false
      end

      it "is true once similar_computed_at is present" do
        ticket = build(:ticket, metadata: { "similar_computed_at" => Time.current.iso8601 })
        expect(ticket.similar_tickets_computed?).to be true
      end
    end

    describe "#similar_tickets_stale?" do
      def computed_metadata(ticket, computed_at: Time.current)
        {
          "similar_computed_for"             => ticket.title,
          "similar_computed_for_description" => ticket.display_description,
          "similar_rules_version"            => Ticket::SIMILAR_TICKETS_RULES_VERSION,
          "similar_computed_at"              => computed_at.iso8601
        }
      end

      it "is stale when never computed" do
        ticket = create(:ticket, :open, metadata: {})
        expect(ticket.similar_tickets_stale?).to be true
      end

      it "is not stale immediately after a fresh computation on an open ticket" do
        ticket = create(:ticket, :open, metadata: {})
        ticket.update_columns(metadata: computed_metadata(ticket))
        expect(ticket.similar_tickets_stale?).to be false
      end

      it "is stale when the title has changed since it was computed" do
        ticket = create(:ticket, :open, title: "Original title", metadata: {})
        ticket.update_columns(metadata: computed_metadata(ticket))
        ticket.update_columns(title: "Changed title")

        expect(ticket.similar_tickets_stale?).to be true
      end

      it "is stale when the display_description has changed since it was computed (e.g. first customer reply arrived)" do
        ticket = create(:ticket, :open, metadata: {})
        ticket.update_columns(metadata: computed_metadata(ticket))
        expect(ticket.similar_tickets_stale?).to be false

        create(:ticket_message, ticket: ticket, sender: ticket.customer, details: "New description text")

        expect(ticket.similar_tickets_stale?).to be true
      end

      it "is stale when the rules version has changed since it was computed" do
        ticket = create(:ticket, :open, metadata: {})
        ticket.update_columns(metadata: computed_metadata(ticket).merge("similar_rules_version" => -1))

        expect(ticket.similar_tickets_stale?).to be true
      end

      it "is not stale for a closed ticket even after the TTL window, as long as title/description/rules are unchanged" do
        ticket = create(:ticket, :closed, metadata: {})
        ticket.update_columns(metadata: computed_metadata(ticket, computed_at: 2.days.ago))

        expect(ticket.similar_tickets_stale?).to be false
      end

      it "is not stale for a cancelled ticket even after the TTL window" do
        ticket = create(:ticket, :cancelled, metadata: {})
        ticket.update_columns(metadata: computed_metadata(ticket, computed_at: 2.days.ago))

        expect(ticket.similar_tickets_stale?).to be false
      end

      it "is stale for an open ticket once the TTL window has passed" do
        ticket = create(:ticket, :open, metadata: {})
        ticket.update_columns(metadata: computed_metadata(ticket, computed_at: Ticket::SIMILAR_TICKETS_TTL.ago - 1.minute))

        expect(ticket.similar_tickets_stale?).to be true
      end

      it "is not stale for an open ticket within the TTL window" do
        ticket = create(:ticket, :open, metadata: {})
        ticket.update_columns(metadata: computed_metadata(ticket, computed_at: 1.minute.ago))

        expect(ticket.similar_tickets_stale?).to be false
      end
    end

    describe "#enqueue_similar_tickets_computation" do
      it "enqueues ComputeSimilarTicketsJob for the ticket" do
        ticket = create(:ticket)
        expect {
          ticket.enqueue_similar_tickets_computation
        }.to have_enqueued_job(ComputeSimilarTicketsJob).with(ticket.id)
      end
    end

    describe "callbacks" do
      it "enqueues similar tickets computation after create" do
        expect {
          create(:ticket)
        }.to have_enqueued_job(ComputeSimilarTicketsJob)
      end

      it "enqueues similar tickets computation again when the title changes" do
        ticket = create(:ticket, title: "Original")
        expect {
          ticket.update!(title: "Changed")
        }.to have_enqueued_job(ComputeSimilarTicketsJob).with(ticket.id)
      end

      it "does not enqueue similar tickets computation again for unrelated changes" do
        ticket = create(:ticket, title: "Original")
        clear_enqueued_jobs

        expect {
          ticket.update!(status: "in_progress")
        }.not_to have_enqueued_job(ComputeSimilarTicketsJob)
      end
    end
  end

  describe "#notify_customer!" do
    let(:customer) { create(:user, :customer) }
    let(:agent)    { create(:user, :agent) }
    let(:ticket)   { create(:ticket, customer: customer) }

    it "creates a notification for the ticket's customer" do
      expect {
        ticket.notify_customer!(responded_by: agent, details: "Update")
      }.to change(TicketNotification, :count).by(1)

      notification = TicketNotification.last
      expect(notification.receiver).to eq(customer)
      expect(notification.responded_by).to eq(agent)
      expect(notification.details).to eq("Update")
      expect(notification.status).to eq("unread")
    end

    it "does not notify when the responder is the customer themselves" do
      expect {
        ticket.notify_customer!(responded_by: customer, details: "Update")
      }.not_to change(TicketNotification, :count)
    end

    it "does not notify when the ticket has no customer" do
      ticket = create(:ticket, customer: nil)
      expect {
        ticket.notify_customer!(responded_by: agent, details: "Update")
      }.not_to change(TicketNotification, :count)
    end
  end

  describe "#notify_staff!" do
    let(:customer) { create(:user, :customer) }

    it "notifies all managers and the assignee" do
      manager1 = create(:user, :manager)
      manager2 = create(:user, :manager)
      agent    = create(:user, :agent)
      ticket   = create(:ticket, customer: customer, assignee: agent)

      expect {
        ticket.notify_staff!(responded_by: customer, details: "Update")
      }.to change(TicketNotification, :count).by(3)

      expect(TicketNotification.find_by(receiver: manager1)).to be_present
      expect(TicketNotification.find_by(receiver: manager2)).to be_present
      expect(TicketNotification.find_by(receiver: agent)).to be_present
    end

    it "sends only one notification to a manager when the ticket is self-assigned to them" do
      manager       = create(:user, :manager)
      other_manager = create(:user, :manager)
      ticket        = create(:ticket, customer: customer, assignee: manager)

      expect {
        ticket.notify_staff!(responded_by: customer, details: "Update")
      }.to change(TicketNotification, :count).by(2) # manager (deduped) + other_manager

      expect(TicketNotification.where(receiver: manager).count).to eq(1)
    end

    it "excludes inactive managers" do
      create(:user, :manager, :inactive)
      ticket = create(:ticket, customer: customer)

      expect {
        ticket.notify_staff!(responded_by: customer, details: "Update")
      }.not_to change(TicketNotification, :count)
    end

    it "does not notify the responder themselves" do
      manager = create(:user, :manager)
      ticket  = create(:ticket, customer: customer, assignee: manager)

      expect {
        ticket.notify_staff!(responded_by: manager, details: "Update")
      }.not_to change(TicketNotification, :count)
    end

    it "does nothing when there are no managers and no assignee" do
      ticket = create(:ticket, customer: customer)
      expect {
        ticket.notify_staff!(responded_by: customer, details: "Update")
      }.not_to change(TicketNotification, :count)
    end
  end
end
