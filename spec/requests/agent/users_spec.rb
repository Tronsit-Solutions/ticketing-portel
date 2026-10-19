require "rails_helper"

RSpec.describe "Agent::Users", type: :request do
  let(:agent)    { create(:user, :agent) }
  let(:customer) { create(:user, :customer) }

  before { sign_in agent }

  describe "GET /agent/users/:id" do
    it "shows an agent's assigned tickets" do
      create(:ticket, :assigned, assignee: agent, title: "Laptop will not boot")
      get agent_user_path(agent)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Assigned Tickets")
      expect(response.body).to include("Laptop will not boot")
    end

    it "shows a customer's raised tickets" do
      create(:ticket, customer: customer, title: "VPN keeps dropping")
      get agent_user_path(customer)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Raised Tickets")
      expect(response.body).to include("VPN keeps dropping")
    end

    it "links to the edit page and offers no admin-only actions" do
      get agent_user_path(customer)

      expect(response.body).to include(edit_agent_user_path(customer))
      expect(response.body).not_to include("Reset Password")
      expect(response.body).not_to include("Recent Activity")
    end
  end
end
