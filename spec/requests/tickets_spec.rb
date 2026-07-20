require "rails_helper"

RSpec.describe "Tickets", type: :request do
  let(:admin)    { create(:user, :admin) }
  let(:agent)    { create(:user, :agent) }
  let(:customer) { create(:user, :customer) }
  let(:other)    { create(:user, :customer) }
  let(:ticket)   { create(:ticket, customer: customer) }

  describe "GET /tickets/catalogue" do
    it "returns 200 for authenticated users" do
      sign_in customer
      get catalogue_tickets_path
      expect(response).to have_http_status(:ok)
    end

    it "redirects unauthenticated users" do
      get catalogue_tickets_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "GET /tickets" do
    context "as admin" do
      before { sign_in admin }

      it "returns 200" do
        get tickets_path
        expect(response).to have_http_status(:ok)
      end

      it "filters by status" do
        get tickets_path, params: { status: "open" }
        expect(response).to have_http_status(:ok)
      end

      it "filters unassigned tickets" do
        get tickets_path, params: { unassigned: true }
        expect(response).to have_http_status(:ok)
      end
    end

    context "as customer" do
      before { sign_in customer }

      it "returns 200 (my_tickets view)" do
        get tickets_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /tickets/:id" do
    context "as admin" do
      it "returns 200" do
        sign_in admin
        get ticket_path(ticket)
        expect(response).to have_http_status(:ok)
      end
    end

    context "as the ticket's customer" do
      it "returns 200" do
        sign_in customer
        get ticket_path(ticket)
        expect(response).to have_http_status(:ok)
      end
    end

    context "as a different customer" do
      it "redirects (unauthorized)" do
        sign_in other
        get ticket_path(ticket)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /tickets/new" do
    it "returns 200 for authenticated users" do
      sign_in customer
      get new_ticket_path, params: { ticket_type: "technical_support" }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /tickets" do
    context "as customer" do
      before { sign_in customer }

      it "creates a ticket and redirects to it" do
        expect {
          post tickets_path, params: {
            ticket: { ticket_type: "technical_support", title: "My Issue", metadata: { details: "Broken" } }
          }
        }.to change(Ticket, :count).by(1)
        expect(response).to redirect_to(ticket_path(Ticket.last))
      end

      it "renders new on invalid params" do
        post tickets_path, params: { ticket: { ticket_type: "technical_support", title: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "redirects hiring ticket to hiring detail form without creating the ticket yet" do
        expect {
          post tickets_path, params: {
            ticket: {
              ticket_type: "hiring_departure",
              title: "New Hire",
              metadata: { request_type: "Hire", full_name: "John Doe" }
            }
          }
        }.not_to change(Ticket, :count)
        expect(response).to redirect_to(new_pending_hiring_detail_path)
      end

      it "redirects termination ticket to termination detail form without creating the ticket yet" do
        expect {
          post tickets_path, params: {
            ticket: {
              ticket_type: "hiring_departure",
              title: "Termination",
              metadata: { request_type: "Termination", full_name: "Jane Doe" }
            }
          }
        }.not_to change(Ticket, :count)
        expect(response).to redirect_to(new_pending_termination_detail_path)
      end

      it "creates notifications for staff on new ticket" do
        staff = create(:user, :agent)
        expect {
          post tickets_path, params: {
            ticket: { ticket_type: "technical_support", title: "Issue", metadata: {} }
          }
        }.to change(TicketNotification, :count).by(1)
      end
    end

    context "as agent creating on behalf of customer" do
      before { sign_in agent }

      it "creates ticket with the selected customer" do
        post tickets_path, params: {
          ticket: {
            ticket_type: "technical_support",
            title: "Agent Created",
            customer_id: customer.id,
            metadata: {}
          }
        }
        expect(Ticket.last.customer).to eq(customer)
        expect(Ticket.last.created_by).to eq(agent)
      end

      it "notifies staff of the new ticket" do
        staff = create(:user, :manager)
        expect {
          post tickets_path, params: {
            ticket: { ticket_type: "technical_support", title: "Agent Created", customer_id: customer.id, metadata: {} }
          }
        }.to change(TicketNotification, :count).by_at_least(1)
        expect(TicketNotification.where(receiver: staff)).to be_present
      end

      it "notifies the customer their ticket was submitted on their behalf" do
        post tickets_path, params: {
          ticket: { ticket_type: "technical_support", title: "Agent Created", customer_id: customer.id, metadata: {} }
        }
        notification = TicketNotification.find_by(receiver: customer)
        expect(notification).to be_present
        expect(notification.responded_by).to eq(agent)
      end
    end
  end

  describe "PATCH /tickets/:id/assign" do
    let(:ticket) { create(:ticket, :open, customer: customer) }

    context "as admin" do
      before { sign_in admin }

      it "assigns the ticket and creates an assignment record" do
        expect {
          patch assign_ticket_path(ticket), params: { assignee_id: agent.id, reason: "Best fit" }
        }.to change(TicketAssignment, :count).by(1)
        expect(ticket.reload.assignee).to eq(agent)
        expect(ticket.reload.status).to eq("in_progress")
      end

      it "redirects to ticket" do
        patch assign_ticket_path(ticket), params: { assignee_id: agent.id }
        expect(response).to redirect_to(ticket_path(ticket))
      end

      it "notifies the customer of the assignment" do
        patch assign_ticket_path(ticket), params: { assignee_id: agent.id }
        notification = TicketNotification.find_by(receiver: customer)
        expect(notification).to be_present
        expect(notification.responded_by).to eq(admin)
      end
    end

    context "as agent" do
      it "is unauthorized" do
        sign_in agent
        patch assign_ticket_path(ticket), params: { assignee_id: agent.id }
        expect(response).to redirect_to(root_path)
      end
    end

    context "as customer" do
      it "is unauthorized" do
        sign_in customer
        patch assign_ticket_path(ticket), params: { assignee_id: agent.id }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "PATCH /tickets/:id/self_assign" do
    let(:ticket) { create(:ticket, :open, customer: customer) }

    context "as agent" do
      before { sign_in agent }

      it "self-assigns the ticket" do
        patch self_assign_ticket_path(ticket)
        expect(ticket.reload.assignee).to eq(agent)
        expect(ticket.reload.status).to eq("in_progress")
      end

      it "creates an assignment record" do
        expect {
          patch self_assign_ticket_path(ticket)
        }.to change(TicketAssignment, :count).by(1)
      end

      it "notifies the customer of the self-assignment" do
        patch self_assign_ticket_path(ticket)
        notification = TicketNotification.find_by(receiver: customer)
        expect(notification).to be_present
        expect(notification.responded_by).to eq(agent)
      end
    end

    context "as customer" do
      it "is unauthorized" do
        sign_in customer
        patch self_assign_ticket_path(ticket)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "PATCH /tickets/:id/close" do
    let(:assigned_ticket) { create(:ticket, :assigned, assignee: agent, customer: customer) }

    context "as the assignee" do
      before { sign_in agent }

      it "closes the ticket" do
        patch close_ticket_path(assigned_ticket), params: { resolution: { how_resolved: "Fixed it" } }
        expect(assigned_ticket.reload.status).to eq("closed")
        expect(assigned_ticket.reload.resolved_by).to eq(agent)
      end

      it "redirects to ticket" do
        patch close_ticket_path(assigned_ticket)
        expect(response).to redirect_to(ticket_path(assigned_ticket))
      end

      it "notifies the customer that their ticket was closed" do
        patch close_ticket_path(assigned_ticket)
        notification = TicketNotification.find_by(receiver: customer)
        expect(notification).to be_present
        expect(notification.responded_by).to eq(agent)
      end
    end

    context "as the customer" do
      it "can close their own ticket" do
        my_ticket = create(:ticket, customer: customer)
        sign_in customer
        patch close_ticket_path(my_ticket)
        expect(my_ticket.reload.status).to eq("closed")
      end

      it "does not notify themselves when they close their own ticket" do
        my_ticket = create(:ticket, customer: customer)
        sign_in customer
        expect {
          patch close_ticket_path(my_ticket)
        }.not_to change(TicketNotification, :count)
      end
    end

    context "as another customer" do
      it "is unauthorized" do
        sign_in other
        patch close_ticket_path(assigned_ticket)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
