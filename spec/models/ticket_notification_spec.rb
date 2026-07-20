require "rails_helper"

RSpec.describe TicketNotification, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:ticket).optional }
    it { is_expected.to belong_to(:responded_by).optional }
    it { is_expected.to belong_to(:receiver).optional }
  end

  describe "validations" do
    it { is_expected.to validate_inclusion_of(:status).in_array(TicketNotification::STATUSES) }

    it "is valid with valid attributes" do
      expect(build(:ticket_notification)).to be_valid
    end

    it "is valid without a ticket" do
      expect(build(:ticket_notification, ticket: nil)).to be_valid
    end

    it "is invalid with unknown status" do
      expect(build(:ticket_notification, status: "pending")).not_to be_valid
    end
  end

  describe "scopes" do
    let(:user)    { create(:user) }
    let(:other)   { create(:user) }
    let!(:unread) { create(:ticket_notification, :unread, receiver: user) }
    let!(:read)   { create(:ticket_notification, :read,   receiver: user) }
    let!(:other_notif) { create(:ticket_notification, receiver: other) }

    it ".unread returns unread notifications" do
      expect(TicketNotification.unread).to include(unread)
      expect(TicketNotification.unread).not_to include(read)
    end

    it ".read returns read notifications" do
      expect(TicketNotification.read).to include(read)
      expect(TicketNotification.read).not_to include(unread)
    end

    it ".for_user filters by receiver" do
      expect(TicketNotification.for_user(user)).to include(unread, read)
      expect(TicketNotification.for_user(user)).not_to include(other_notif)
    end

    it ".recent orders descending by created_at" do
      notifs = TicketNotification.recent.to_a
      expect(notifs).to eq(notifs.sort_by(&:created_at).reverse)
    end
  end

  describe "instance methods" do
    it "#unread? returns true when status is unread" do
      expect(build(:ticket_notification, :unread).unread?).to be true
    end

    it "#read? returns true when status is read" do
      expect(build(:ticket_notification, :read).read?).to be true
    end
  end
end
