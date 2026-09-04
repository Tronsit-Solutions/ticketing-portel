# Finds other tickets that mean the same thing as a given ticket, scoped to
# the same category. Titles can be worded completely differently
# ("printer won't print" vs "unable to print documents"), so plain string
# matching isn't enough — this compares sentence embeddings (via
# TicketEmbedder) instead of asking an LLM to judge each pair. Embeddings
# run locally, so there's no API key, no rate limit, and results are
# deterministic given the same inputs.
#
# Title is checked first, since it's the most direct signal of "same
# issue". Only when a candidate's title doesn't match do we fall back to
# comparing descriptions — two tickets can have very differently worded
# titles but describe the identical underlying problem in the body text.
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
  # mean the same thing as @ticket, by title or (failing that) description.
  # Returns [] if there's nothing to compare against.
  def call
    candidates = fetch_candidates
    return [] if candidates.empty?

    target_title_vector = TicketEmbedder.embed(@ticket.title)
    target_description  = @ticket.display_description

    candidates.filter_map do |candidate|
      if cosine_similarity(target_title_vector, title_embedding_for(candidate)) >= SIMILARITY_THRESHOLD
        candidate.id
      elsif target_description.present?
        candidate_description_vector = description_embedding_for(candidate)
        next if candidate_description_vector.nil?

        target_description_vector ||= TicketEmbedder.embed(target_description)
        candidate.id if cosine_similarity(target_description_vector, candidate_description_vector) >= SIMILARITY_THRESHOLD
      end
    end
  end

  private

  # Returns same-category tickets that have actually been resolved (closed,
  # with resolution text) — an unresolved or resolution-less ticket has
  # nothing useful to show in the similar-tickets modal, so it's not worth
  # surfacing as a match.
  #
  # Deliberately not using find_each here: it always paginates by primary
  # key ascending and ignores any explicit order/limit on the relation, so
  # it would silently scan the oldest tickets instead of the most recent
  # CANDIDATE_LIMIT — the whole point of the ordering below.
  def fetch_candidates
    Ticket.where(ticket_type: @ticket.ticket_type, status: "closed")
          .where.not(id: @ticket.id).where.not(resolution: [nil, ""])
          .order(created_at: :desc).limit(CANDIDATE_LIMIT)
  end

  def title_embedding_for(candidate)
    vector = candidate.metadata["title_embedding"]
    return vector if vector.present? && candidate.metadata["title_embedding_for"] == candidate.title

    vector = TicketEmbedder.embed(candidate.title)
    candidate.update_columns(
      metadata: candidate.metadata.merge(
        "title_embedding"     => vector,
        "title_embedding_for" => candidate.title
      )
    )
    vector
  end

  def description_embedding_for(candidate)
    description = candidate.display_description
    return nil if description.blank?

    vector = candidate.metadata["description_embedding"]
    return vector if vector.present? && candidate.metadata["description_embedding_for"] == description

    vector = TicketEmbedder.embed(description)
    candidate.update_columns(
      metadata: candidate.metadata.merge(
        "description_embedding"     => vector,
        "description_embedding_for" => description
      )
    )
    vector
  end

  def cosine_similarity(a, b)
    dot = a.zip(b).sum { |x, y| x * y }
    norm_a = Math.sqrt(a.sum { |x| x**2 })
    norm_b = Math.sqrt(b.sum { |y| y**2 })
    return 0.0 if norm_a.zero? || norm_b.zero?

    dot / (norm_a * norm_b)
  end
end
