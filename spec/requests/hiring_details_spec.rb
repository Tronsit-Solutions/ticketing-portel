require "rails_helper"

RSpec.describe "HiringDetails", type: :request do
  let(:customer) { create(:user, :customer) }
  let(:ticket)   { create(:ticket, :hiring_departure, customer: customer) }

  before { sign_in customer }

  describe "GET /tickets/:ticket_id/hiring_detail/new" do
    it "returns 200" do
      get new_ticket_hiring_detail_path(ticket)
      expect(response).to have_http_status(:ok)
    end

    it "redirects if hiring detail already exists" do
      create(:hiring_detail, ticket: ticket)
      get new_ticket_hiring_detail_path(ticket)
      expect(response).to redirect_to(ticket_path(ticket))
    end

    it "redirects if ticket is not hiring_departure type" do
      other_ticket = create(:ticket, :technical_support, customer: customer)
      get new_ticket_hiring_detail_path(other_ticket)
      expect(response).to redirect_to(ticket_path(other_ticket))
    end
  end

  describe "POST /tickets/:ticket_id/hiring_detail" do
    it "creates hiring detail and redirects to ticket" do
      expect {
        post ticket_hiring_detail_path(ticket), params: {
          hiring_detail: { start_date: 2.weeks.from_now.to_date, title_position: "Care Coordinator I", department: "NYMAN", pc_requirement: "They Need A New Pc" }
        }
      }.to change(HiringDetail, :count).by(1)
      expect(response).to redirect_to(ticket_path(ticket))
    end

    it "redirects if hiring detail already exists" do
      create(:hiring_detail, ticket: ticket)
      post ticket_hiring_detail_path(ticket), params: { hiring_detail: { title_position: "Care Coordinator I" } }
      expect(response).to redirect_to(ticket_path(ticket))
    end

    it "saves provider-specific fields when is_provider is true" do
      post ticket_hiring_detail_path(ticket), params: {
        hiring_detail: {
          start_date: 2.weeks.from_now.to_date, title_position: "Physician", department: "NYMAN",
          pc_requirement: "They Need A New Pc", is_provider: "true",
          billing_provider_name: "Dr. Jane Smith", provider_npi: "1234567890", q5_q6_modifier_required: "true",
          q5_q6_modifier: "Q6"
        }
      }
      hiring_detail = ticket.reload.hiring_detail
      expect(hiring_detail.is_provider?).to eq(true)
      expect(hiring_detail.billing_provider_name).to eq("Dr. Jane Smith")
      expect(hiring_detail.provider_npi).to eq("1234567890")
      expect(hiring_detail.q5_q6_modifier_required?).to eq(true)
      expect(hiring_detail.q5_q6_modifier).to eq("Q6")
    end

    it "saves multiple selected Microsoft Teams" do
      create(:team, name: "Human Resources")
      create(:team, name: "Operations")

      post ticket_hiring_detail_path(ticket), params: {
        hiring_detail: {
          start_date: 2.weeks.from_now.to_date, title_position: "Care Coordinator I", department: "NYMAN",
          pc_requirement: "They Need A New Pc",
          microsoft_teams_department: ["Human Resources", "Operations"]
        }
      }
      hiring_detail = ticket.reload.hiring_detail
      expect(hiring_detail.microsoft_teams_department).to contain_exactly("Human Resources", "Operations")
    end
  end

  describe "manager creating a hiring ticket on behalf of a customer" do
    let(:manager) { create(:user, :manager) }

    before do
      sign_in manager
      post tickets_path, params: {
        ticket: {
          ticket_type: "hiring_departure", title: "New Hire", customer_id: customer.id,
          metadata: { request_type: "Hire", full_name: "Jane Doe" }
        }
      }
    end

    it "notifies staff and the customer once the pending ticket is submitted" do
      staff = create(:user, :agent)
      expect {
        post pending_hiring_detail_path, params: {
          hiring_detail: {
            start_date: 2.weeks.from_now.to_date, title_position: "Care Coordinator I",
            department: "NYMAN", pc_requirement: "They Need A New Pc"
          }
        }
      }.to change(TicketNotification, :count).by_at_least(2)

      ticket = Ticket.last
      expect(TicketNotification.find_by(ticket: ticket, receiver: staff)).to be_present
      customer_notification = TicketNotification.find_by(ticket: ticket, receiver: customer)
      expect(customer_notification).to be_present
      expect(customer_notification.responded_by).to eq(manager)
    end

    it "does not auto-assign the ticket" do
      post pending_hiring_detail_path, params: {
        hiring_detail: {
          start_date: 2.weeks.from_now.to_date, title_position: "Care Coordinator I",
          department: "NYMAN", pc_requirement: "They Need A New Pc"
        }
      }
      ticket = Ticket.last
      expect(ticket.assignee).to be_nil
      expect(ticket.status).to eq("open")
    end
  end

  describe "agent creating a hiring ticket on behalf of a customer" do
    let(:agent) { create(:user, :agent) }

    before do
      sign_in agent
      post tickets_path, params: {
        ticket: {
          ticket_type: "hiring_departure", title: "New Hire", customer_id: customer.id,
          metadata: { request_type: "Hire", full_name: "Jane Doe" }
        }
      }
    end

    it "auto self-assigns the ticket once the pending ticket is submitted" do
      post pending_hiring_detail_path, params: {
        hiring_detail: {
          start_date: 2.weeks.from_now.to_date, title_position: "Care Coordinator I",
          department: "NYMAN", pc_requirement: "They Need A New Pc"
        }
      }
      ticket = Ticket.last
      expect(ticket.assignee).to eq(agent)
      expect(ticket.status).to eq("in_progress")
      expect(ticket.ticket_assignments.last.assigned_to).to eq(agent)
    end
  end
end
