# Finds other tickets that mean the same thing as a given ticket's title,
# scoped to the same category. Titles can be worded completely differently
# ("printer won't print" vs "unable to print documents"), so plain string
# matching isn't enough — this compares sentence embeddings (via
# TicketEmbedder) instead of asking an LLM to judge each pair. Embeddings
# run locally, so there's no API key, no rate limit, and results are
# deterministic given the same titles.
class SimilarTicketFinder
  CANDIDATE_LIMIT = 200

  # Cosine similarity above this is treated as "same meaning". Chosen from
  # testing: genuine paraphrase matches scored 0.67-0.96, unrelated titles
  # scored 0.04-0.17, and "merely same topic" titles (e.g. "Password reset"
  # against an authentication-update ticket) landed around 0.5 — 0.6 sits
  # above that topical-overlap band without excluding real paraphrases.
  SIMILARITY_THRESHOLD = 0.6

  def initialize(ticket)
    @ticket = ticket
  end

  # Returns an array of ticket ids (within the candidate set) judged to
  # mean the same thing as @ticket's title. Returns [] if there's nothing
  # to compare against.
  def call
    candidates = fetch_candidates
    return [] if candidates.empty?

    target_vector = TicketEmbedder.embed(@ticket.title)

    candidates.filter_map do |id, vector|
      similarity = cosine_similarity(target_vector, vector)
      id if similarity >= SIMILARITY_THRESHOLD
    end
  end

  private

  # Returns [[id, embedding_vector], ...] for same-category tickets,
  # computing (and persisting) any embeddings that aren't cached yet.
  #
  # Deliberately not using find_each here: it always paginates by primary
  # key ascending and ignores any explicit order/limit on the relation, so
  # it would silently scan the oldest tickets instead of the most recent
  # CANDIDATE_LIMIT — the whole point of the ordering below.
  def fetch_candidates
    candidates = Ticket.where(ticket_type: @ticket.ticket_type).where.not(id: @ticket.id)
                        .order(created_at: :desc).limit(CANDIDATE_LIMIT)

    candidates.filter_map do |candidate|
      vector = candidate.metadata["title_embedding"]
      if vector.blank? || candidate.metadata["title_embedding_for"] != candidate.title
        vector = TicketEmbedder.embed(candidate.title)
        candidate.update_columns(
          metadata: candidate.metadata.merge(
            "title_embedding"     => vector,
            "title_embedding_for" => candidate.title
          )
        )
      end
      [candidate.id, vector]
    end
  end

  def cosine_similarity(a, b)
    dot = a.zip(b).sum { |x, y| x * y }
    norm_a = Math.sqrt(a.sum { |x| x**2 })
    norm_b = Math.sqrt(b.sum { |y| y**2 })
    return 0.0 if norm_a.zero? || norm_b.zero?

    dot / (norm_a * norm_b)
  end
end
