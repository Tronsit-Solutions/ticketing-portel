require "rails_helper"

RSpec.describe "TerminationDetails", type: :request do
  let(:customer) { create(:user, :customer) }
  let(:ticket) do
    create(:ticket, :hiring_departure, customer: customer, metadata: { "request_type" => "Termination" })
  end

  before { sign_in customer }

  describe "GET /tickets/:ticket_id/termination_detail/new" do
    it "returns 200" do
      get new_ticket_termination_detail_path(ticket)
      expect(response).to have_http_status(:ok)
    end

    it "redirects if termination detail already exists" do
      create(:termination_detail, ticket: ticket)
      get new_ticket_termination_detail_path(ticket)
      expect(response).to redirect_to(ticket_path(ticket))
    end

    it "redirects if ticket is not a termination request" do
      other = create(:ticket, :hiring_departure, customer: customer, metadata: { "request_type" => "Hire" })
      get new_ticket_termination_detail_path(other)
      expect(response).to redirect_to(ticket_path(other))
    end
  end

  describe "POST /tickets/:ticket_id/termination_detail" do
    it "creates termination detail and redirects to ticket" do
      expect {
        post ticket_termination_detail_path(ticket), params: {
          termination_detail: {
            termination_reason: "Voluntary Resignation",
            termination_date:   1.week.from_now.to_date,
            termination_time:   "5:00 PM",
            email_address:      "emp@example.com"
          }
        }
      }.to change(TerminationDetail, :count).by(1)
      expect(response).to redirect_to(ticket_path(ticket))
    end

    it "redirects if termination detail already exists" do
      create(:termination_detail, ticket: ticket)
      post ticket_termination_detail_path(ticket), params: { termination_detail: { termination_reason: "Other" } }
      expect(response).to redirect_to(ticket_path(ticket))
    end
  end
end
