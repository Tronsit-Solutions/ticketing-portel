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
        expect(ticket.title).to eq("Bright Idea: Workflow")
      end

      it "uses fallback title when idea_types is empty" do
        ticket = build(:ticket, ticket_type: "bright_ideas", title: "", metadata: {})
        ticket.valid?
        expect(ticket.title).to eq("Bright Idea")
      end

      it "auto-generates title for great_work if blank" do
        ticket = build(:ticket, ticket_type: "great_work", title: "", metadata: { "work_types" => ["Teamwork"] })
        ticket.valid?
        expect(ticket.title).to eq("Great Work: Teamwork")
      end

      it "auto-generates title for lms if blank" do
        ticket = build(:ticket, ticket_type: "lms", title: "")
        ticket.valid?
        expect(ticket.title).to eq("Password Reset for LMS")
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
end
