require "rails_helper"

RSpec.describe TeamsNotifier do
  let(:webhook_url) { "https://example.webhook.office.com/webhookb2/abc?sig=123" }
  let(:http)        { instance_double(Net::HTTP, :use_ssl= => nil, :open_timeout= => nil, :read_timeout= => nil) }

  around do |example|
    original = ENV["TEAMS_WEBHOOK_URL"]
    example.run
  ensure
    ENV["TEAMS_WEBHOOK_URL"] = original
  end

  let(:message) do
    {
      event:     "created",
      reference: "#1 · Technical Support",
      subject:   "Printer is down",
      summary:   "**Jane** submitted a new ticket",
      facts:     { "Requester" => "Jane", "Location" => nil, "Status" => "Open" },
      url:       "http://example.com/tickets/1"
    }
  end

  before { allow(Net::HTTP).to receive(:new).and_return(http) }

  describe ".deliver" do
    it "does nothing when no webhook url is configured" do
      ENV["TEAMS_WEBHOOK_URL"] = ""

      expect(described_class.deliver(**message)).to be(false)
      expect(Net::HTTP).not_to have_received(:new)
    end

    it "posts an adaptive card to the webhook" do
      ENV["TEAMS_WEBHOOK_URL"] = webhook_url
      sent = nil
      allow(http).to receive(:request) { |request| sent = request; Net::HTTPAccepted.new("1.1", "202", "Accepted") }

      expect(described_class.deliver(**message)).to be(true)

      expect(Net::HTTP).to have_received(:new).with("example.webhook.office.com", 443)
      expect(sent.path).to eq("/webhookb2/abc?sig=123")
      card = JSON.parse(sent.body).dig("attachments", 0, "content")
      expect(card["body"].filter_map { |block| block["text"] }).to eq(["Printer is down", "**Jane** submitted a new ticket"])
      expect(card["actions"].first["url"]).to eq("http://example.com/tickets/1")
    end

    it "raises when Teams rejects the message" do
      ENV["TEAMS_WEBHOOK_URL"] = webhook_url
      allow(http).to receive(:request).and_return(Net::HTTPBadRequest.new("1.1", "400", "Bad Request"))

      expect { described_class.deliver(**message) }.to raise_error(TeamsNotifier::Error, /400/)
    end
  end

  describe ".payload" do
    def card(**overrides)
      described_class.payload(**message, **overrides).dig("attachments", 0, "content")
    end

    it "themes the header band by event" do
      header = card(event: "closed")["body"].first

      expect(header["style"]).to eq("good")
      expect(header.to_json).to include("Ticket closed", "#1 · Technical Support")
    end

    it "falls back to a neutral header for an unknown event" do
      expect(card(event: "mystery")["body"].first.to_json).to include("Ticket update")
    end

    it "lists facts in order, skipping blank ones" do
      fact_set = card["body"].find { |block| block["type"] == "FactSet" }

      expect(fact_set["facts"]).to eq([
        { "title" => "Requester", "value" => "Jane" },
        { "title" => "Status",    "value" => "Open" }
      ])
    end

    it "adds a labelled quote block only when there is a quote" do
      expect(card["body"].size).to eq(4)

      quoted = card(quote: "Replaced the toner", quote_label: "Resolution")["body"][3]
      expect(quoted["items"].map { |item| item["text"] }).to eq(["RESOLUTION", "Replaced the toner"])
    end

    it "omits the button without a url" do
      expect(card(url: nil)).not_to have_key("actions")
    end
  end
end
