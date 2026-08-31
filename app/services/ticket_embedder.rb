require "informers"

# Turns a ticket title into a sentence embedding — a vector that captures
# meaning, not just wording, so "Authenticator update" and "Updating of
# authentication" end up close together even though they share almost no
# characters. Runs fully locally (no API key, no network call, no rate
# limit): the model downloads once to ~/.cache/informers and is reused
# from then on.
class TicketEmbedder
  MODEL = "sentence-transformers/all-MiniLM-L6-v2".freeze

  class << self
    def embed(text)
      pipeline.(text.to_s)
    end

    private

    def pipeline
      @pipeline ||= Informers.pipeline("embedding", MODEL)
    end
  end
end
