require "rails_helper"

RSpec.describe "TicketNotifications", type: :request do
  let(:user)    { create(:user) }
  let(:other)   { create(:user) }
  let(:ticket)  { create(:ticket, customer: user) }
  let!(:notif)  { create(:ticket_notification, :unread, receiver: user, ticket: ticket) }
  let!(:other_notif) { create(:ticket_notification, :unread, receiver: other) }

  before { sign_in user }

  describe "GET /ticket_notifications" do
    it "returns 200" do
      get ticket_notifications_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /ticket_notifications/:id/mark_read" do
    it "marks the notification as read" do
      patch mark_read_ticket_notification_path(notif)
      expect(notif.reload.status).to eq("read")
    end

    it "redirects to the ticket" do
      patch mark_read_ticket_notification_path(notif)
      expect(response).to redirect_to(ticket_path(ticket))
    end

    it "cannot mark another user's notification (404)" do
      patch mark_read_ticket_notification_path(other_notif)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /ticket_notifications/mark_all_read" do
    it "marks all unread notifications for current user as read" do
      patch mark_all_read_ticket_notifications_path
      expect(notif.reload.status).to eq("read")
      expect(other_notif.reload.status).to eq("unread")
    end

    it "redirects to notifications index" do
      patch mark_all_read_ticket_notifications_path
      expect(response).to redirect_to(ticket_notifications_path)
    end
  end
end
