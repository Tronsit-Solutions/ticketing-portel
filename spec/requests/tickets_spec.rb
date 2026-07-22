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

    context "as manager filtering by assignment" do
      let(:manager) { create(:user, :manager) }

      before { sign_in manager }

      it "shows only tickets self-assigned to the current manager" do
        mine       = create(:ticket, assignee: manager)
        not_mine   = create(:ticket, assignee: agent)
        unassigned = create(:ticket)

        get tickets_path, params: { assignment: "self_assigned" }
        expect(response.body).to include(mine.title)
        expect(response.body).not_to include(not_mine.title)
        expect(response.body).not_to include(unassigned.title)
      end

      it "shows only unassigned tickets via the combined assignment filter" do
        unassigned = create(:ticket)
        assigned   = create(:ticket, assignee: manager)

        get tickets_path, params: { assignment: "unassigned" }
        expect(response.body).to include(unassigned.title)
        expect(response.body).not_to include(assigned.title)
      end
    end

    context "as customer" do
      before { sign_in customer }

      it "returns 200 (my_tickets view)" do
        get tickets_path
        expect(response).to have_http_status(:ok)
      end

      it "paginates open tickets, 10 per page" do
        tickets = Array.new(12) { create(:ticket, :open, customer: customer) }.sort_by(&:created_at).reverse

        get tickets_path
        expect(response.body).to include(tickets[9].title)   # 10th most recent, on page 1
        expect(response.body).not_to include(tickets[10].title) # 11th most recent, pushed to page 2
        expect(response.body).to include("12") # open tab count

        get tickets_path, params: { page: 2 }
        expect(response.body).to include(tickets[10].title)
        expect(response.body).to include(tickets[11].title)
      end

      it "paginates closed tickets separately via the closed tab" do
        5.times { create(:ticket, :closed, customer: customer) }
        3.times { create(:ticket, :open, customer: customer) }

        get tickets_path, params: { tab: "closed" }
        expect(response.body).to include("5") # closed tab count
        expect(response.body).to include("3") # open tab count
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

    context "when the ticket is closed" do
      it "shows the closed date/time and resolver name next to the status pill, to admin" do
        closed_ticket = create(:ticket, :assigned, assignee: agent, customer: customer)
        sign_in admin
        patch close_ticket_path(closed_ticket)

        get ticket_path(closed_ticket)
        expect(response.body).to include("closed on")
        expect(response.body).to include("by #{admin.fullname}")
        expect(response.body).to include("Closed By")
      end

      it "shows the closed date/time and resolver name next to the status pill, to manager" do
        manager = create(:user, :manager)
        closed_ticket = create(:ticket, :assigned, assignee: manager, customer: customer)
        sign_in manager
        patch close_ticket_path(closed_ticket)

        get ticket_path(closed_ticket)
        expect(response.body).to include("closed on")
        expect(response.body).to include("by #{manager.fullname}")
      end

      it "does not show closed info for an open ticket" do
        sign_in admin
        get ticket_path(ticket)
        expect(response.body).not_to include("closed on")
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
              ticket_type: "hiring",
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
              ticket_type: "hiring",
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

      it "auto self-assigns the ticket to the agent" do
        post tickets_path, params: {
          ticket: { ticket_type: "technical_support", title: "Agent Created", customer_id: customer.id, metadata: {} }
        }
        ticket = Ticket.last
        expect(ticket.assignee).to eq(agent)
        expect(ticket.assigned_by).to eq(agent)
        expect(ticket.status).to eq("in_progress")
        expect(ticket.ticket_assignments.last.assigned_to).to eq(agent)
        expect(ticket.ticket_assignments.last.reason).to eq("Self-assigned")
      end
    end

    context "as manager creating on behalf of customer" do
      let(:manager) { create(:user, :manager) }

      before { sign_in manager }

      it "does not auto-assign the ticket" do
        post tickets_path, params: {
          ticket: { ticket_type: "technical_support", title: "Manager Created", customer_id: customer.id, metadata: {} }
        }
        ticket = Ticket.last
        expect(ticket.created_by).to eq(manager)
        expect(ticket.assignee).to be_nil
        expect(ticket.status).to eq("open")
        expect(ticket.ticket_assignments).to be_empty
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

    context "as manager" do
      let(:manager) { create(:user, :manager) }

      before { sign_in manager }

      it "can assign the ticket to themselves" do
        patch assign_ticket_path(ticket), params: { assignee_id: manager.id }
        expect(ticket.reload.assignee).to eq(manager)
        expect(ticket.reload.status).to eq("in_progress")
      end

      it "can assign the ticket to an agent" do
        patch assign_ticket_path(ticket), params: { assignee_id: agent.id }
        expect(ticket.reload.assignee).to eq(agent)
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

      it "does not allow grabbing a cancelled ticket" do
        cancelled_ticket = create(:ticket, :cancelled, customer: customer)
        patch self_assign_ticket_path(cancelled_ticket)
        expect(cancelled_ticket.reload.assignee).to be_nil
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Cancelled tickets cannot be grabbed.")
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

  describe "PATCH /tickets/:id/cancel" do
    let(:manager)        { create(:user, :manager) }
    let(:assigned_ticket) { create(:ticket, :assigned, assignee: agent, customer: customer) }

    context "as the ticket's customer" do
      before { sign_in customer }

      it "cancels the ticket by marking it closed" do
        patch cancel_ticket_path(assigned_ticket)
        expect(assigned_ticket.reload.status).to eq("closed")
        expect(assigned_ticket.reload.resolved_by).to eq(customer)
      end

      it "redirects to the ticket" do
        patch cancel_ticket_path(assigned_ticket)
        expect(response).to redirect_to(ticket_path(assigned_ticket))
      end

      it "notifies the assignee and managers" do
        manager
        patch cancel_ticket_path(assigned_ticket)
        expect(TicketNotification.find_by(ticket: assigned_ticket, receiver: agent)).to be_present
        expect(TicketNotification.find_by(ticket: assigned_ticket, receiver: manager)).to be_present
      end

      it "does not notify the customer themselves" do
        patch cancel_ticket_path(assigned_ticket)
        expect(TicketNotification.find_by(ticket: assigned_ticket, receiver: customer)).to be_nil
      end
    end

    context "as admin" do
      it "can cancel any ticket" do
        sign_in admin
        patch cancel_ticket_path(assigned_ticket)
        expect(assigned_ticket.reload.status).to eq("closed")
      end
    end

    context "as an unrelated customer" do
      it "is unauthorized" do
        sign_in other
        patch cancel_ticket_path(assigned_ticket)
        expect(response).to redirect_to(root_path)
        expect(assigned_ticket.reload.status).not_to eq("closed")
      end
    end

    context "as the assignee (agent, not the customer)" do
      it "is unauthorized" do
        sign_in agent
        patch cancel_ticket_path(assigned_ticket)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
