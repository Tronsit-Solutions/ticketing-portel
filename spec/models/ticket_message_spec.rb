require "rails_helper"

RSpec.describe TicketMessage, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:ticket) }
    it { is_expected.to belong_to(:sender).optional }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:details) }
    it { is_expected.to validate_inclusion_of(:message_type).in_array(TicketMessage::MESSAGE_TYPES) }

    it "is valid with valid attributes" do
      expect(build(:ticket_message)).to be_valid
    end

    it "is invalid with an unknown message_type" do
      expect(build(:ticket_message, message_type: "spam")).not_to be_valid
    end
  end

  describe "scopes" do
    let!(:visible_message)  { create(:ticket_message, internal_note: false) }
    let!(:internal_message) { create(:ticket_message, :internal_note) }

    it ".visible excludes internal notes" do
      expect(TicketMessage.visible).to include(visible_message)
      expect(TicketMessage.visible).not_to include(internal_message)
    end

    it ".internal_notes includes only internal notes" do
      expect(TicketMessage.internal_notes).to include(internal_message)
      expect(TicketMessage.internal_notes).not_to include(visible_message)
    end

    it ".recent orders ascending by created_at" do
      msgs = TicketMessage.recent.to_a
      expect(msgs).to eq(msgs.sort_by(&:created_at))
    end
  end
end
