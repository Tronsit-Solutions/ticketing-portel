namespace :migrate do
  desc "Enrich ticket title, location and metadata from first HTML message body"
  task enrich_tickets: :environment do
    HTML_PATTERN = /<\s*(p|br|div|span|ul|ol|li|strong|em|a|img|table|tr|td|h[1-6])\b/i
    GREEN_DOT    = "\e[32m.\e[0m".freeze

    def dot
      $stdout.print GREEN_DOT
      $stdout.flush
    end

    def clean_key(key)
      key.to_s.strip.downcase.gsub(/[^a-z0-9_]/, "_")
    end

    def clean_value(value)
      return nil if value.blank?
      value.to_s.strip.gsub(/\s+/, " ").gsub(/\s*,\s*/, ", ")
    end

    with_html     = 0
    without_html  = 0
    updated       = 0
    skipped       = 0
    errors        = 0

    puts "\n==> Enriching tickets from first message HTML"

    Ticket.includes(:ticket_messages, :location).find_each do |ticket|
      first_message = ticket.ticket_messages.min_by(&:created_at)

      unless first_message
        skipped += 1
        dot
        next
      end

      unless HTML_PATTERN.match?(first_message.details.to_s)
        without_html += 1
        dot
        next
      end

      with_html += 1

      begin
        clean_details = first_message.details.gsub(/\r\n/, " ").gsub(/\n/, " ")
        raw_data = clean_details.scan(/<p[^>]*>\s*([^:<>]+?)\s*:\s*(.*?)<\/p>/i).to_h

        cleaned_data = raw_data
          .transform_keys { |k| clean_key(k) }
          .transform_values { |v| clean_value(v) }
          .compact

        changed = false

        if cleaned_data["title"].present?
          ticket.title = cleaned_data["title"]
          changed = true
        end

        if cleaned_data["location"].present? && ticket.location.nil?
          location = Location.find_by("LOWER(name) = ?", cleaned_data["location"].downcase)
          if location
            ticket.location = location
            changed = true
          end
        end

        mapped_keys = %w[title status location fullname]
        remaining   = cleaned_data.except(*mapped_keys)

        unless remaining.empty?
          ticket.metadata = ticket.metadata.merge(remaining)
          changed = true
        end

        if changed
          ticket.save!(validate: false)
          updated += 1
        end
        dot
      rescue => e
        puts "  ERROR ticket ##{ticket.id}: #{e.message}"
        errors += 1
      end
    end

    puts "\n#{'=' * 50}"
    puts "Enrich complete!"
    puts "  With HTML:    #{with_html}"
    puts "  Without HTML: #{without_html}"
    puts "  Updated:      #{updated}"
    puts "  Skipped:      #{skipped}"
    puts "  Errors:       #{errors}"
    puts "#{'=' * 50}"
  end
end
