require "rails_helper"

RSpec.describe TeamsNotificationJob, type: :job do
  let(:message) { { event: "created", subject: "Printer is down", summary: "**Jane** submitted a new ticket", url: "http://example.com/tickets/1" } }

  describe "#perform" do
    it "delivers the message through TeamsNotifier" do
      allow(TeamsNotifier).to receive(:deliver)

      described_class.perform_now(**message)

      expect(TeamsNotifier).to have_received(:deliver).with(**message)
    end

    it "swallows delivery failures" do
      allow(TeamsNotifier).to receive(:deliver).and_raise(TeamsNotifier::Error, "Teams webhook responded 500")

      expect { described_class.perform_now(**message) }.not_to raise_error
    end
  end
end
