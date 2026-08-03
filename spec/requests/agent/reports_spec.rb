require "rails_helper"

RSpec.describe "Agent::Reports", type: :request do
  let(:agent)    { create(:user, :agent) }
  let(:customer) { create(:user, :customer) }
  let(:team)     { create(:team) }
  let(:other_agent) { create(:user, :agent, fullname: "Alice Agent", team: team, is_active: true) }

  before do
    create(:ticket, assignee: other_agent, status: "open")
    create(:ticket, assignee: other_agent, status: "closed")
  end

  describe "GET /agent/reports (tickets tab)" do
    it "returns 200 for a signed-in agent" do
      sign_in agent
      get agent_reports_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ticket Reports")
    end

    it "redirects away for a customer" do
      sign_in customer
      get agent_reports_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /agent/reports?report=agents" do
    it "returns 200 and renders the agents report" do
      sign_in agent
      get agent_reports_path(report: "agents")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Agent Reports")
      expect(response.body).to include("Alice Agent")
    end
  end

  describe "GET /agent/reports.csv?report=agents" do
    it "streams a CSV with agent stats" do
      sign_in agent
      get agent_reports_path(format: :csv, report: "agents")
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/csv")
      expect(response.body).to include("Alice Agent")
    end
  end
end
