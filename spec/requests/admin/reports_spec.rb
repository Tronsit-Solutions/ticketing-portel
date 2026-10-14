require "rails_helper"

RSpec.describe "Admin::Reports", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:team)  { create(:team) }
  let(:agent) { create(:user, :agent, fullname: "Alice Agent", team: team, is_active: true) }

  before do
    sign_in admin
    create(:ticket, assignee: agent, status: "open")
    create(:ticket, assignee: agent, status: "closed")
  end

  describe "GET /admin/reports (tickets tab)" do
    it "returns 200 and renders the tickets report" do
      get admin_reports_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ticket Reports")
    end

    it "shows the ticket title and description" do
      ticket = create(:ticket, assignee: agent, title: "VPN not connecting")
      ticket.update!(details: "Cannot connect to the VPN since this morning.")

      get admin_reports_path
      expect(response.body).to include("VPN not connecting")
      expect(response.body).to include("Cannot connect to the VPN since this morning.")
    end

    it "shows a dash when the ticket has no description" do
      create(:ticket, assignee: agent, title: "No details ticket")

      get admin_reports_path
      expect(response.body).to include("No details ticket")
    end
  end

  describe "GET /admin/reports (tickets tab) agent column and filter" do
    let(:other_agent) { create(:user, :agent, fullname: "Bob Other") }

    before do
      create(:ticket, assignee: agent,       title: "Alice's ticket")
      create(:ticket, assignee: other_agent, title: "Bob's ticket")
      create(:ticket, assignee: nil,         title: "Nobody's ticket")
    end

    it "shows the assigned agent's name, or Unassigned" do
      get admin_reports_path
      expect(response.body).to include("Alice Agent")
      expect(response.body).to include("Bob Other")
      expect(response.body).to include("Unassigned")
    end

    it "filters by assignee_id" do
      get admin_reports_path(assignee_id: agent.id)
      expect(response.body).to include("Alice&#39;s ticket")
      expect(response.body).not_to include("Bob&#39;s ticket")
      expect(response.body).not_to include("Nobody&#39;s ticket")
    end

    it "filters to unassigned tickets" do
      get admin_reports_path(assignee_id: "unassigned")
      expect(response.body).to include("Nobody&#39;s ticket")
      expect(response.body).not_to include("Alice&#39;s ticket")
    end

    it "includes the agent in the CSV and honours the filter" do
      get admin_reports_path(format: :csv, assignee_id: other_agent.id)
      expect(response.body).to include("Customer (email),Agent,Location")
      expect(response.body).to include("Bob Other")
      expect(response.body).not_to include("Alice's ticket")
    end
  end

  describe "GET /admin/reports?report=agents" do
    it "returns 200 and renders the agents report with counts" do
      get admin_reports_path(report: "agents")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Agent Reports")
      expect(response.body).to include("Alice Agent")
      expect(response.body).to include(team.name)
    end

    it "filters by team_id" do
      other_agent = create(:user, :agent, fullname: "Bob Other")
      get admin_reports_path(report: "agents", team_id: team.id)
      expect(response.body).to include("Alice Agent")
      expect(response.body).not_to include("Bob Other")
    end

    it "filters by agent_status" do
      inactive_agent = create(:user, :agent, fullname: "Charlie Inactive", is_active: false)
      get admin_reports_path(report: "agents", agent_status: "false")
      expect(response.body).to include("Charlie Inactive")
      expect(response.body).not_to include("Alice Agent")
    end

    it "filters by search" do
      get admin_reports_path(report: "agents", search: "alice")
      expect(response.body).to include("Alice Agent")
    end

    it "shows an empty state when no agents match" do
      get admin_reports_path(report: "agents", search: "zzz-no-match")
      expect(response.body).to include("No agents found")
    end

    it "shows the agent's joining date" do
      agent.update!(created_at: Date.new(2025, 6, 15))
      get admin_reports_path(report: "agents")
      expect(response.body).to include("Jun 15, 2025")
    end

    it "filters by joined_start_date and joined_end_date" do
      agent.update!(created_at: Date.new(2020, 1, 1))
      recent_agent = create(:user, :agent, fullname: "Dana Recent", created_at: Date.new(2025, 6, 1))

      get admin_reports_path(report: "agents", joined_start_date: "2025-01-01", joined_end_date: "2025-12-31")
      expect(response.body).to include("Dana Recent")
      expect(response.body).not_to include("Alice Agent")
    end
  end

  describe "GET /admin/reports.csv?report=agents" do
    it "streams a CSV with agent stats" do
      get admin_reports_path(format: :csv, report: "agents")
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/csv")
      expect(response.body).to include("Agent,Email,Team,Status,Joining Date,Open,Closed,Total")
      expect(response.body).to include("Alice Agent")
    end
  end

  describe "GET /admin/reports?report=agent_detail" do
    it "returns 200 and renders the agent's details and their tickets" do
      ticket = create(:ticket, assignee: agent, title: "VPN not connecting")

      get admin_reports_path(report: "agent_detail", agent_id: agent.id)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alice Agent&#39;s Report")
      expect(response.body).to include("Alice Agent")
      expect(response.body).to include(agent.email)
      expect(response.body).to include(team.name)
      expect(response.body).to include("VPN not connecting")
    end

    it "only shows tickets assigned to that agent" do
      other_agent = create(:user, :agent, fullname: "Other Agent")
      create(:ticket, assignee: other_agent, title: "Not mine")

      get admin_reports_path(report: "agent_detail", agent_id: agent.id)
      expect(response.body).not_to include("Not mine")
    end

    it "filters the agent's tickets by status" do
      create(:ticket, assignee: agent, title: "Open one", status: "open")
      create(:ticket, assignee: agent, title: "Closed one", status: "closed")

      get admin_reports_path(report: "agent_detail", agent_id: agent.id, status: "closed")
      expect(response.body).to include("Closed one")
      expect(response.body).not_to include("Open one")
    end

    it "redirects with an alert when the agent does not exist" do
      get admin_reports_path(report: "agent_detail", agent_id: -1)
      expect(response).to redirect_to(admin_reports_path(report: "agents"))
    end

    it "redirects when the given user is not an agent" do
      customer = create(:user, :customer)
      get admin_reports_path(report: "agent_detail", agent_id: customer.id)
      expect(response).to redirect_to(admin_reports_path(report: "agents"))
    end
  end

  describe "GET /admin/reports.csv?report=agent_detail" do
    it "streams a CSV with the agent's details followed by their tickets" do
      create(:ticket, assignee: agent, title: "VPN not connecting")

      get admin_reports_path(format: :csv, report: "agent_detail", agent_id: agent.id)
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/csv")
      expect(response.body).to include("Agent Details")
      expect(response.body).to include("Alice Agent")
      expect(response.body).to include("Tickets")
      expect(response.body).to include("VPN not connecting")
    end
  end
end
