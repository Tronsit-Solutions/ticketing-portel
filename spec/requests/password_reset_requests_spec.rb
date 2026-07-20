require "rails_helper"

RSpec.describe "PasswordResetRequests", type: :request do
  describe "GET /password_reset_requests/new" do
    it "returns 200 without requiring authentication" do
      get new_password_reset_request_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /password_reset_requests" do
    it "notifies all active admins and managers when the email matches a user" do
      customer         = create(:user, :customer, email: "jane@example.com")
      admin            = create(:user, :admin)
      manager          = create(:user, :manager)
      inactive_manager = create(:user, :manager, :inactive)
      agent            = create(:user, :agent)

      expect {
        post password_reset_requests_path, params: { email: "jane@example.com" }
      }.to change(TicketNotification, :count).by(2)

      expect(TicketNotification.find_by(receiver: admin)).to be_present
      expect(TicketNotification.find_by(receiver: manager)).to be_present
      expect(TicketNotification.find_by(receiver: inactive_manager)).to be_nil
      expect(TicketNotification.find_by(receiver: agent)).to be_nil

      notification = TicketNotification.find_by(receiver: admin)
      expect(notification.details).to include(customer.fullname)
      expect(notification.details).to include(customer.email)
      expect(notification.ticket).to be_nil
      expect(notification.responded_by).to eq(customer)
    end

    it "matches email case-insensitively" do
      create(:user, :customer, email: "jane@example.com")
      create(:user, :admin)

      expect {
        post password_reset_requests_path, params: { email: "JANE@EXAMPLE.COM" }
      }.to change(TicketNotification, :count).by(1)
    end

    it "does not create notifications and does not error when the email does not match any user" do
      create(:user, :admin)
      expect {
        post password_reset_requests_path, params: { email: "nobody@example.com" }
      }.not_to change(TicketNotification, :count)
      expect(response).to redirect_to(new_password_reset_request_path)
    end

    it "shows the same confirmation message regardless of whether the email matched" do
      post password_reset_requests_path, params: { email: "nobody@example.com" }
      follow_redirect!
      expect(response.body).to include("our team has been notified")
    end
  end
end
