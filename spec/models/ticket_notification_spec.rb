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

  describe "real-time broadcasts", type: :model do
    let(:receiver) { create(:user, :manager) }

    # after_commit callbacks don't fire inside RSpec's transactional test wrapper
    # (the transaction is rolled back, never truly committed), so these specs
    # invoke the model's private broadcast methods directly rather than relying
    # on Rails to trigger them via a real commit.
    it "broadcasts the new row and the badge (topbar + sidebar) to the receiver's stream when created" do
      notification = build(:ticket_notification, :unread, receiver: receiver)

      expect(notification).to receive(:broadcast_prepend_later_to).with(
        [receiver, :ticket_notifications],
        hash_including(target: "notif-list", partial: "ticket_notifications/notification")
      )
      expect(notification).to receive(:broadcast_replace_later_to).with(
        [receiver, :ticket_notifications],
        hash_including(target: "notif-bell-badge", partial: "shared/notification_bell_badge")
      )
      expect(notification).to receive(:broadcast_replace_later_to).with(
        [receiver, :ticket_notifications],
        hash_including(target: "notif-bell-badge-sidebar", partial: "shared/notification_bell_badge")
      )

      notification.send(:broadcast_created)
    end

    it "broadcasts an updated badge (topbar + sidebar) when the status changes" do
      notification = build(:ticket_notification, :unread, receiver: receiver)

      expect(notification).to receive(:broadcast_replace_later_to).with(
        [receiver, :ticket_notifications],
        hash_including(target: "notif-bell-badge")
      )
      expect(notification).to receive(:broadcast_replace_later_to).with(
        [receiver, :ticket_notifications],
        hash_including(target: "notif-bell-badge-sidebar")
      )

      notification.send(:broadcast_badge)
    end

    it "only broadcasts the topbar badge (no sidebar) for a non-manager receiver" do
      agent_receiver = create(:user, :agent)
      notification = build(:ticket_notification, :unread, receiver: agent_receiver)

      expect(notification).to receive(:broadcast_replace_later_to).once.with(
        [agent_receiver, :ticket_notifications],
        hash_including(target: "notif-bell-badge")
      )

      notification.send(:broadcast_badge)
    end

    it "does not broadcast when there is no receiver" do
      notification = build(:ticket_notification, :unread, receiver: nil)

      expect(notification).not_to receive(:broadcast_prepend_later_to)
      expect(notification).not_to receive(:broadcast_replace_later_to)

      notification.send(:broadcast_created)
    end

    it "uses ms-auto badge styling for a customer receiver" do
      customer_receiver = create(:user, :customer)
      notification = build(:ticket_notification, :unread, receiver: customer_receiver)

      expect(notification).to receive(:broadcast_replace_later_to).with(
        [customer_receiver, :ticket_notifications],
        hash_including(locals: hash_including(badge_class: "ms-auto"))
      )

      notification.send(:broadcast_badge)
    end

  end
end
