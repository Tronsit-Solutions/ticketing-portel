require "rails_helper"

RSpec.describe "TicketMessages", type: :request do
  let(:customer) { create(:user, :customer) }
  let(:agent)    { create(:user, :agent) }
  let(:other)    { create(:user, :customer) }
  let(:ticket)   { create(:ticket, customer: customer, assignee: agent) }

  describe "POST /tickets/:ticket_id/ticket_messages" do
    context "as the ticket's customer" do
      before { sign_in customer }

      it "creates a customer_reply and redirects" do
        expect {
          post ticket_ticket_messages_path(ticket), params: { details: "My reply" }
        }.to change(TicketMessage, :count).by(1)
        expect(TicketMessage.last.message_type).to eq("customer_reply")
        expect(response).to redirect_to(ticket_path(ticket))
      end

      it "does not notify the customer of their own reply" do
        post ticket_ticket_messages_path(ticket), params: { details: "My reply" }
        expect(TicketNotification.find_by(receiver: customer)).to be_nil
      end

      it "notifies the assigned agent and all managers of the reply" do
        manager = create(:user, :manager)

        expect {
          post ticket_ticket_messages_path(ticket), params: { details: "My reply" }
        }.to change(TicketNotification, :count).by(2)

        expect(TicketNotification.find_by(receiver: agent)).to be_present
        expect(TicketNotification.find_by(receiver: manager)).to be_present
      end

      it "sends only one notification to a manager when the ticket is self-assigned to them" do
        manager_ticket = create(:ticket, customer: customer, assignee: create(:user, :manager))
        assigned_manager = manager_ticket.assignee

        expect {
          post ticket_ticket_messages_path(manager_ticket), params: { details: "My reply" }
        }.to change(TicketNotification, :count).by(1)

        expect(TicketNotification.where(receiver: assigned_manager).count).to eq(1)
      end
    end

    context "as an agent" do
      before { sign_in agent }

      it "creates an agent_reply" do
        post ticket_ticket_messages_path(ticket), params: { details: "Agent reply" }
        expect(TicketMessage.last.message_type).to eq("agent_reply")
      end

      it "creates an internal_note when flagged" do
        post ticket_ticket_messages_path(ticket), params: { details: "Internal", internal_note: "true" }
        expect(TicketMessage.last.internal_note).to be true
      end

      it "notifies the customer of the reply" do
        expect {
          post ticket_ticket_messages_path(ticket), params: { details: "Agent reply" }
        }.to change(TicketNotification, :count).by(1)

        notification = TicketNotification.last
        expect(notification.receiver).to eq(customer)
        expect(notification.responded_by).to eq(agent)
      end

      it "does not notify the customer for an internal note" do
        expect {
          post ticket_ticket_messages_path(ticket), params: { details: "Internal", internal_note: "true" }
        }.not_to change(TicketNotification, :count)
      end
    end

    context "as the assigned manager" do
      let(:manager) { create(:user, :manager) }
      let(:ticket)  { create(:ticket, customer: customer, assignee: manager) }

      before { sign_in manager }

      it "creates an agent_reply, not a customer_reply" do
        post ticket_ticket_messages_path(ticket), params: { details: "Manager reply" }
        expect(TicketMessage.last.message_type).to eq("agent_reply")
      end

      it "notifies the customer of the reply" do
        expect {
          post ticket_ticket_messages_path(ticket), params: { details: "Manager reply" }
        }.to change(TicketNotification, :count).by(1)

        notification = TicketNotification.last
        expect(notification.receiver).to eq(customer)
        expect(notification.responded_by).to eq(manager)
      end

      it "does not notify the customer for an internal note" do
        expect {
          post ticket_ticket_messages_path(ticket), params: { details: "Internal", internal_note: "true" }
        }.not_to change(TicketNotification, :count)
      end
    end

    context "as an unrelated customer" do
      it "is unauthorized" do
        sign_in other
        post ticket_ticket_messages_path(ticket), params: { details: "Hack" }
        expect(response).to redirect_to(root_path)
      end
    end

    context "when not signed in" do
      it "redirects to sign-in" do
        post ticket_ticket_messages_path(ticket), params: { details: "Test" }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
