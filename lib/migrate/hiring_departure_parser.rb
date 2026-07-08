module Migrate
  class HiringDepartureParser
    HTML_PATTERN = /<\s*(p|br|div|span|ul|ol|li|strong|em|a|img|table|tr|td|h[1-6])\b/i

    class << self
      def structured_message_for(ticket)
        ticket.ticket_messages
          .sort_by(&:created_at)
          .find do |message|
            body = message.details.to_s
            next false unless HTML_PATTERN.match?(body)

            fields = parse_html_fields(body)
            fields["FULLNAME"].present? || fields["STATUS"].present?
          end
      end

      def apply!(ticket, fields, django_ticket_type: nil)
        return nil unless fields["FULLNAME"].present? || fields["STATUS"].present?

        kind = hiring_or_termination(fields, django_ticket_type || infer_django_type(ticket, fields))
        return nil unless kind

        request_type = kind == :hire ? "New Hire" : "Termination"
        update_ticket_metadata!(ticket, fields, request_type)

        case kind
        when :hire
          ticket.termination_detail&.destroy
          upsert_hiring_detail!(ticket, fields)
          :hire
        when :termination
          ticket.hiring_detail&.destroy
          upsert_termination_detail!(ticket, fields)
          :termination
        end
      end

      def parse_html_fields(html)
        html.scan(/<p[^>]*>(.*?)<\/p>/i).each_with_object({}) do |(chunk), h|
          chunk_clean = chunk.gsub(/<[^>]+>/, "").strip
          next if chunk_clean.blank?

          if chunk_clean.include?(":")
            key, _, val = chunk_clean.partition(":")
            key = key.strip
            val = val.strip
          elsif (m = chunk_clean.match(/\AIf existing PC,?\s*who was using before\s+(.+)\z/i))
            key = "If existing PC,who was using before"
            val = m[1].strip
          else
            next
          end

          next if key.blank?

          h[key] = val
        end
      end

      def hiring_detail_attributes(fields)
        provider_answer = field_lookup(
          fields,
          "Will they be a Billing provider ?",
          "Will they be a Billing provider?"
        )

        {
          start_date:                 parse_date(field_lookup(fields, "START DATE")),
          date_of_birth:              parse_date(field_lookup(fields, "Date of Birth")),
          title_position:             field_lookup(fields, "POSITION", "Title/Position", "Title"),
          is_provider:                yes_no?(provider_answer),
          department:                 field_lookup(fields, "DEPARTMENT", "Please select their Department"),
          gender:                     field_lookup(fields, "GENDER", "Gender"),
          cell_phone:                 field_lookup(fields, "CONTACT", "Cell Phone Number", "Mobile"),
          badge_number:               field_lookup(
            fields,
            "BADGE NO",
            "What is the badge/key card number",
            "What is the badge/keycard Number"
          ),
          credentials_send_to:        field_lookup(
            fields,
            "CREDENTIALS",
            "Who should we send their credentials to if anyone",
            "Who shoud we send their credentials to if anyone"
          ),
          existing_pc_user:           field_lookup(
            fields,
            "EXISTING PC USER",
            "If existing PC , Who was using before",
            "If existing PC,who was using before  HP Computer- recent user-Elizabeth Galaviz. But you currently have under"
          ),
          pc_requirement:             field_lookup(
            fields,
            "PC REUIREMENTS",
            "PC REQUIREMENTS",
            "PC Requirements"
          ),
          additional_info:            field_lookup(
            fields,
            "USEFUL INFO",
            "Any other information that would be useful to know",
            "Any other information that would be useful to know:(Application/FOB) ?Number/Special Setup/Requirement)"
          ),
          microsoft_teams_department: reject_none(
            field_lookup(
              fields,
              "MICROSOFT TEAMS",
              "What Microsoft Teams should the member be a part of"
            )
          ).join(", ").presence,
          access_systems:             reject_none(
            field_lookup(fields, "ACCESS SYSTEMS", "What Access/Systems Are Needed")
          ),
          distribution_groups:        reject_none(
            field_lookup(
              fields,
              "DISTRIBUTION",
              "What Distribution Groups should the new team mate be added to if any"
            )
          ),
        }
      end

      def termination_detail_attributes(fields)
        {
          termination_reason:      field_lookup(fields, "TERMINATION REASON", "REASON"),
          termination_date:        parse_date(field_lookup(fields, "TERMINATION DATE")),
          termination_time:        field_lookup(fields, "TERMINATION TIME"),
          email_address:           field_lookup(fields, "EMAIL", "EMAIL ADDRESS"),
          key_card:                field_lookup(fields, "KEY CARD", "Keycard"),
          email_forwarded_to:      field_lookup(fields, "EMAIL FORWARDED TO", "FORWARDED TO"),
          additional_instructions: field_lookup(fields, "USEFUL INFO", "ADDITIONAL INFO", "MISSED INFO"),
        }
      end

      private

      def upsert_hiring_detail!(ticket, fields)
        attrs = hiring_detail_attributes(fields)
        if ticket.hiring_detail
          ticket.hiring_detail.update!(attrs)
        else
          ticket.create_hiring_detail!(attrs)
        end
      end

      def upsert_termination_detail!(ticket, fields)
        attrs = termination_detail_attributes(fields)
        if ticket.termination_detail
          ticket.termination_detail.update!(attrs)
        else
          ticket.create_termination_detail!(attrs)
        end
      end

      def infer_django_type(ticket, fields)
        case ticket.metadata["request_type"]
        when "Termination" then "Termination"
        when "New Hire"      then "Hiring"
        else
          status = field_lookup(fields, "STATUS").to_s.strip.downcase
          return "Termination" if %w[termination terminate departure].include?(status)
          return "Hiring"        if status == "hire"
          return "Termination"   if field_lookup(fields, "TERMINATION DATE").present?
          return "Termination"   if ticket.termination_detail.present?
          return "Hiring"        if ticket.hiring_detail.present?

          "Hiring"
        end
      end

      def field_lookup(fields, *keys)
        keys.each do |key|
          val = fields[key]
          return val if val.present?
        end
        nil
      end

      def to_list(val)
        return [] if val.blank?

        Array(val).flat_map { |item| item.to_s.split(",").map(&:strip) }.reject(&:blank?)
      end

      def reject_none(values)
        to_list(values).reject { |v| v.casecmp?("none") || v.casecmp?("n/a") }
      end

      def parse_date(val)
        return nil if val.blank?

        Date.parse(val.to_s)
      rescue StandardError
        nil
      end

      def yes_no?(val)
        val.to_s.strip.downcase.in?(%w[yes y true 1])
      end

      def update_hiring_departure_ticket!(ticket, fields, request_type)
        full_name = field_lookup(fields, "FULLNAME")
        ticket.metadata = ticket.metadata.merge(
          "request_type" => request_type,
          "full_name"    => full_name
        )
        ticket.title = "#{request_type}: #{full_name}" if full_name.present?
        ticket.save!(validate: false)
      end

      def hiring_or_termination(fields, django_ticket_type)
        status = field_lookup(fields, "STATUS").to_s.strip.downcase
        return :hire        if status == "hire"
        return :termination if %w[termination terminate departure].include?(status)
        return :termination if django_ticket_type == "Termination"
        return :hire        if django_ticket_type == "Hiring"
        return :hire        if field_lookup(fields, "FULLNAME").present? && field_lookup(fields, "TERMINATION DATE").blank?
        return :termination if field_lookup(fields, "TERMINATION REASON", "REASON", "TERMINATION DATE").present?

        nil
      end
    end
  end
end
