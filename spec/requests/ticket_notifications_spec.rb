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

    it "paginates notifications, 25 per page" do
      notifications = Array.new(30) { create(:ticket_notification, receiver: user, details: SecureRandom.hex(8)) }
      notifications_by_recency = ([notif] + notifications).sort_by(&:created_at).reverse

      get ticket_notifications_path
      expect(response.body).to include(notifications_by_recency[24].details)
      expect(response.body).not_to include(notifications_by_recency[25].details)

      get ticket_notifications_path, params: { page: 2 }
      expect(response.body).to include(notifications_by_recency[25].details)
      expect(response.body).to include(notifications_by_recency[30].details)
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

    it "redirects to the notifications index for a ticket-less notification with no responder" do
      ticketless = create(:ticket_notification, :unread, receiver: user, ticket: nil, responded_by: nil)
      patch mark_read_ticket_notification_path(ticketless)
      expect(response).to redirect_to(ticket_notifications_path)
    end
  end

  describe "PATCH /ticket_notifications/:id/mark_read for a password-reset request notification" do
    let(:customer) { create(:user, :customer) }

    it "redirects a manager to the customer's manager-portal show page" do
      manager = create(:user, :manager)
      notification = create(:ticket_notification, :unread, receiver: manager, responded_by: customer, ticket: nil)
      sign_in manager

      patch mark_read_ticket_notification_path(notification)
      expect(response).to redirect_to(manager_user_path(customer))
    end

    it "redirects an admin to the admin-portal show page" do
      admin = create(:user, :admin)
      notification = create(:ticket_notification, :unread, receiver: admin, responded_by: customer, ticket: nil)
      sign_in admin

      patch mark_read_ticket_notification_path(notification)
      expect(response).to redirect_to(user_path(customer))
    end
  end

  describe "GET /ticket_notifications/unread_count" do
    it "returns the current user's unread count as JSON" do
      get unread_count_ticket_notifications_path
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["count"]).to eq(1)
    end

    it "reflects newly created notifications without a page reload" do
      get unread_count_ticket_notifications_path
      expect(JSON.parse(response.body)["count"]).to eq(1)

      create(:ticket_notification, :unread, receiver: user)

      get unread_count_ticket_notifications_path
      expect(JSON.parse(response.body)["count"]).to eq(2)
    end

    it "does not include another user's notifications" do
      get unread_count_ticket_notifications_path
      expect(JSON.parse(response.body)["count"]).to eq(1) # not 2, excludes other_notif
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
