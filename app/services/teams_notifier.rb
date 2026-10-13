require "net/http"

# Posts a ticket activity card to the Microsoft Teams channel behind
# TEAMS_WEBHOOK_URL. Sent as an Adaptive Card, which both the Power Automate
# "Workflows" webhooks and the older Office 365 connector webhooks accept.
class TeamsNotifier
  class Error < StandardError; end

  TIMEOUT = 5

  # Per-event look of the card's header band. `style` is an Adaptive Card
  # container style, which Teams renders as a tinted background that follows
  # the reader's light/dark theme.
  THEMES = {
    "created"    => { icon: "🎫", headline: "New ticket",        style: "accent"    },
    "assigned"   => { icon: "👤", headline: "Ticket assigned",   style: "warning"   },
    "reassigned" => { icon: "🔁", headline: "Ticket reassigned", style: "warning"   },
    "replied"    => { icon: "💬", headline: "New reply",         style: "emphasis"  },
    "noted"      => { icon: "📝", headline: "Internal note",     style: "emphasis"  },
    "details"    => { icon: "📋", headline: "Details submitted", style: "accent"    },
    "closed"     => { icon: "✅", headline: "Ticket closed",     style: "good"      },
    "cancelled"  => { icon: "🚫", headline: "Ticket cancelled",  style: "attention" }
  }.freeze
  DEFAULT_THEME = { icon: "🔔", headline: "Ticket update", style: "emphasis" }.freeze

  class << self
    def enabled?
      webhook_url.present?
    end

    def deliver(**message)
      return false unless enabled?

      uri  = URI.parse(webhook_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = uri.scheme == "https"
      http.open_timeout = TIMEOUT
      http.read_timeout = TIMEOUT

      request = Net::HTTP::Post.new(uri.request_uri, "Content-Type" => "application/json")
      request.body = payload(**message).to_json

      response = http.request(request)
      raise Error, "Teams webhook responded #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      true
    end

    # event     - key into THEMES, picks the header band
    # reference - small line under the headline, e.g. "#42 · Technical Support"
    # subject   - the ticket title
    # summary   - one sentence saying who did what (Markdown allowed)
    # facts     - ordered { "Label" => "value" } pairs; blank values are dropped
    # quote     - optional free text (a reply, a resolution…) shown in a
    #             shaded block under quote_label
    def payload(event:, subject:, summary:, reference: nil, facts: {}, quote: nil, quote_label: nil, url: nil)
      theme = THEMES.fetch(event.to_s, DEFAULT_THEME)

      body = [header(theme, reference)]
      body << { "type" => "TextBlock", "text" => subject, "size" => "Large", "weight" => "Bolder", "wrap" => true, "spacing" => "Medium" }
      body << { "type" => "TextBlock", "text" => summary, "wrap" => true, "spacing" => "Small" }
      body << quote_block(quote, quote_label) if quote.present?

      fact_rows = facts.to_h.select { |_, value| value.present? }
      if fact_rows.any?
        body << {
          "type"      => "FactSet",
          "spacing"   => "Medium",
          "separator" => true,
          "facts"     => fact_rows.map { |label, value| { "title" => label.to_s, "value" => value.to_s } }
        }
      end

      card = {
        "$schema" => "http://adaptivecards.io/schemas/adaptive-card.json",
        "type"    => "AdaptiveCard",
        "version" => "1.4",
        "msteams" => { "width" => "Full" },
        "body"    => body
      }
      card["actions"] = [{ "type" => "Action.OpenUrl", "title" => "View ticket", "url" => url }] if url.present?

      {
        "type"        => "message",
        "attachments" => [
          { "contentType" => "application/vnd.microsoft.card.adaptive", "content" => card }
        ]
      }
    end

    private

    def header(theme, reference)
      titles = [{ "type" => "TextBlock", "text" => theme[:headline], "size" => "Medium", "weight" => "Bolder", "wrap" => true }]
      if reference.present?
        titles << { "type" => "TextBlock", "text" => reference, "size" => "Small", "isSubtle" => true, "spacing" => "None", "wrap" => true }
      end

      {
        "type"  => "Container",
        "style" => theme[:style],
        "bleed" => true,
        "items" => [
          {
            "type"    => "ColumnSet",
            "columns" => [
              {
                "type"  => "Column",
                "width" => "auto",
                "verticalContentAlignment" => "Center",
                "items" => [{ "type" => "TextBlock", "text" => theme[:icon], "size" => "ExtraLarge" }]
              },
              {
                "type"  => "Column",
                "width" => "stretch",
                "verticalContentAlignment" => "Center",
                "items" => titles
              }
            ]
          }
        ]
      }
    end

    def quote_block(quote, label)
      items = []
      if label.present?
        items << { "type" => "TextBlock", "text" => label.to_s.upcase, "size" => "Small", "weight" => "Bolder", "isSubtle" => true }
      end
      items << { "type" => "TextBlock", "text" => quote, "wrap" => true, "spacing" => "Small" }

      { "type" => "Container", "style" => "emphasis", "spacing" => "Medium", "items" => items }
    end

    def webhook_url
      ENV["TEAMS_WEBHOOK_URL"].presence
    end
  end
end
