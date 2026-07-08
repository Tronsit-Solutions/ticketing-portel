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
          hiring_detail: { start_date: 2.weeks.from_now.to_date, title_position: "Nurse", department: "Clinical", pc_requirement: "They Need A New Pc" }
        }
      }.to change(HiringDetail, :count).by(1)
      expect(response).to redirect_to(ticket_path(ticket))
    end

    it "redirects if hiring detail already exists" do
      create(:hiring_detail, ticket: ticket)
      post ticket_hiring_detail_path(ticket), params: { hiring_detail: { title_position: "Nurse" } }
      expect(response).to redirect_to(ticket_path(ticket))
    end
  end
end
