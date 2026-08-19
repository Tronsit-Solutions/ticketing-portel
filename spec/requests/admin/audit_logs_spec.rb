require "rails_helper"

RSpec.describe "Admin::AuditLogs", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe "GET /admin/audit_logs/:id" do
    it "renders a create log with only id and label, not the full schema" do
      team = create(:team, name: "Support Team")
      log = AuditLog.where(action: AuditLog::CREATE, auditable: team).last!

      get admin_audit_log_path(log)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Support Team")
      expect(response.body).to include("Id")
      expect(response.body).to include("Label")
      expect(response.body).not_to include("Created At")
      expect(response.body).not_to include("Updated At")
    end

    it "renders an update log as a from/to diff table" do
      team = create(:team, name: "Old Name")
      team.update!(name: "New Name")
      log = AuditLog.where(action: AuditLog::UPDATE, auditable: team).last!

      get admin_audit_log_path(log)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("From")
      expect(response.body).to include("To")
      expect(response.body).to include("Old Name")
      expect(response.body).to include("New Name")
    end

    it "renders a destroy log with the prior full snapshot" do
      team = create(:team, name: "Doomed Team")
      team.destroy!
      log = AuditLog.where(action: AuditLog::DESTROY, category: AuditLog::TEAMS).last!

      get admin_audit_log_path(log)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Doomed Team")
    end

    it "renders a flat changed_data hash (e.g. ticket assignment) as a key/value table" do
      customer = create(:user, :customer)
      agent    = create(:user, :agent, fullname: "Assignee Agent")
      ticket   = create(:ticket, customer: customer)
      ticket.ticket_assignments.create!(assigned_to: agent, assigned_by: admin, reason: "Picking this up")
      log = AuditLog.where(action: AuditLog::ASSIGNED).last!

      get admin_audit_log_path(log)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Assignee Agent")
      expect(response.body).to include("Picking this up")
    end
  end
end
