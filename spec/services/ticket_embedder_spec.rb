require "rails_helper"

RSpec.describe TicketEmbedder do
  # Stub the informers pipeline itself so specs never load the real ONNX
  # model (slow, and requires the model to be cached on disk).
  after do
    TicketEmbedder.instance_variable_set(:@pipeline, nil)
  end

  def stub_pipeline
    pipeline = double("informers_pipeline")
    allow(Informers).to receive(:pipeline).with("embedding", TicketEmbedder::MODEL).and_return(pipeline)
    pipeline
  end

  describe ".embed" do
    it "delegates the given text to the informers pipeline and returns its vector" do
      pipeline = stub_pipeline
      allow(pipeline).to receive(:call).with("Printer will not print").and_return([0.1, 0.2, 0.3])

      expect(TicketEmbedder.embed("Printer will not print")).to eq([0.1, 0.2, 0.3])
    end

    it "coerces non-string input to a string before embedding" do
      pipeline = stub_pipeline
      allow(pipeline).to receive(:call).with("123").and_return([0.0])

      expect(TicketEmbedder.embed(123)).to eq([0.0])
    end

    it "memoizes the pipeline across multiple calls instead of reloading the model each time" do
      pipeline = stub_pipeline
      allow(pipeline).to receive(:call).and_return([0.0])

      TicketEmbedder.embed("first")
      TicketEmbedder.embed("second")

      expect(Informers).to have_received(:pipeline).once
    end
  end
end
