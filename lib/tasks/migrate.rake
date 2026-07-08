# Migrates legacy Django JSON fixtures from ticketing-portel-json-data/ into Rails.
#
# Run with:
#   rails migrate:json_data
#
# WARNING: This task clears all existing data before importing. Do not run
# against a production database unless you intend to replace all records.
#
# NOTE: Django passwords use PBKDF2-SHA256, which is incompatible with
# Devise/bcrypt. All imported users receive a random password. Ask them to
# reset via "Forgot Password."

namespace :migrate do
  desc "Migrate data from legacy JSON files in ticketing-portel-json-data/"
  task json_data: :environment do
    require "json"
    require "bcrypt"

    DATA_DIR = Rails.root.join("ticketing-portel-json-data")

    # ── Type / status mappings ───────────────────────────────────────────
    TICKET_TYPE_MAP = {
      "Technical"      => "technical_support",
      "Tronshealth"    => "tronshealth",
      "EHR Suggestion" => "tronshealth",
      "CareCloud"      => "carecloud",
      "CureMD"         => "curemd",
      "Bright Ideas"   => "bright_ideas",
      "Great Work"     => "great_work",
      "General HR"     => "hr",
      "Hiring"         => "hiring_departure",
      "Termination"    => "hiring_departure",
      "LMS"            => "lms",
    }.freeze

    STATUS_MAP = {
      "Open"  => "open",
      "Close" => "closed",
    }.freeze

    def load_json(filename)
      puts "  Loading #{filename}..."
      JSON.parse(File.read(DATA_DIR.join(filename)))
    end

    GREEN_DOT = "\e[32m.\e[0m".freeze

    def dot
      $stdout.print GREEN_DOT
      $stdout.flush
    end

    def parse_datetime(date_str, time_str)
      DateTime.parse("#{date_str}T#{time_str}Z")
    rescue StandardError
      Time.current
    end

    # Parses "<p>KEY : value</p>..." into { "KEY" => "value", ... }
    # Comma-separated values are returned as arrays.
    def parse_html_fields(html)
      html.scan(/<p[^>]*>(.*?)<\/p>/i).each_with_object({}) do |(chunk), h|
        next unless chunk.include?(":")
        key, _, val = chunk.partition(":")
        key = key.gsub(/<[^>]+>/, "").strip
        val = val.gsub(/<[^>]+>/, "").strip
        next if key.blank?
        h[key] = val.include?(",") ? val.split(",").map(&:strip).reject(&:blank?) : val
      end
    end

    def create_hiring_detail(ticket, fields)
      start_date = begin
        Date.parse(fields["START DATE"].to_s)
      rescue StandardError
        nil
      end

      access_raw = Array(fields["ACCESS SYSTEMS"])
      dist_raw   = Array(fields["DISTRIBUTION"])

      HiringDetail.create!(
        ticket_id:                  ticket.id,
        start_date:                 start_date,
        title_position:             fields["POSITION"].presence,
        department:                 fields["DEPARTMENT"].presence,
        gender:                     fields["GENDER"].presence,
        cell_phone:                 fields["CONTACT"].presence,
        badge_number:               fields["BADGE NO"].presence,
        credentials_send_to:        fields["CREDENTIALS"].presence,
        existing_pc_user:           fields["EXISTING PC USER"].presence,
        pc_requirement:             fields["PC REUIREMENTS"].presence || fields["PC REQUIREMENTS"].presence,
        additional_info:            fields["USEFUL INFO"].presence,
        microsoft_teams_department: Array(fields["MICROSOFT TEAMS"]).join(", ").presence,
        access_systems:             access_raw.reject { |v| v.casecmp?("none") },
        distribution_groups:        dist_raw.reject { |v| v.casecmp?("none") },
      )
    end

    def create_termination_detail(ticket, fields)
      term_date = begin
        Date.parse(fields["TERMINATION DATE"].to_s)
      rescue StandardError
        nil
      end

      TerminationDetail.create!(
        ticket_id:               ticket.id,
        termination_reason:      fields["TERMINATION REASON"].presence || fields["REASON"].presence,
        termination_date:        term_date,
        termination_time:        fields["TERMINATION TIME"].presence,
        email_address:           fields["EMAIL"].presence || fields["EMAIL ADDRESS"].presence,
        key_card:                fields["KEY CARD"].presence,
        email_forwarded_to:      fields["EMAIL FORWARDED TO"].presence,
        additional_instructions: fields["USEFUL INFO"].presence || fields["ADDITIONAL INFO"].presence,
      )
    end

    MEDIA_DIR = Rails.root.join("media")

    # ── Clear existing data (in dependency order) ────────────────────────
    puts "\n==> Clearing existing data"
    TicketNotification.delete_all
    TicketMessage.delete_all
    TicketAssignment.delete_all
    HiringDetail.delete_all
    TerminationDetail.delete_all
    ActiveStorage::Attachment.where(record_type: "Ticket").each(&:purge)
    Ticket.delete_all
    User.delete_all
    Team.delete_all
    Location.delete_all
    puts "    All tables cleared."

    puts "\n==> Loading JSON files"
    users_raw       = load_json("users.json")
    my_users_raw    = load_json("my_users.json")
    teams_raw       = load_json("teams.json")
    locations_raw   = load_json("locations.json")
    tickets_raw     = load_json("tickets.json")
    details_raw     = load_json("ticket_details.json")
    notifs_raw      = load_json("ticket_notifications.json")
    ticket_files_raw = load_json("ticket_files.json")

    # ── 1. Locations ─────────────────────────────────────────────────────
    puts "\n==> Migrating locations"
    location_id_map = {}

    locations_raw.each do |rec|
      f = rec["fields"]
      loc = Location.find_or_create_by!(name: f["name"]) do |l|
        l.abbreviation = f["abbreviation"]
        l.state        = f["state"]
        l.is_active    = f["is_active"]
      end
      location_id_map[rec["pk"]] = loc.id
      dot
    end
    puts "\n    #{location_id_map.size} locations done."

    # ── 2. Teams ─────────────────────────────────────────────────────────
    puts "\n==> Migrating teams"
    teams_raw.each { |rec| Team.find_or_create_by!(name: rec["fields"]["name"]) && dot }
    puts "\n    #{teams_raw.size} teams done."

    # ── 3. Users ─────────────────────────────────────────────────────────
    puts "\n==> Migrating users"
    my_user_index = my_users_raw.each_with_object({}) do |rec, h|
      h[rec["fields"]["my_user"]] = rec["fields"]
    end

    imported_users = 0

    users_raw.each do |rec|
      f       = rec["fields"]
      email   = f["username"].to_s.downcase.strip
      next if email.blank?

      profile = my_user_index[rec["pk"]] || {}

      role = if f["is_superuser"] || profile["is_admin"]
               "admin"
             elsif profile["is_manager"]
               "manager"
             elsif profile["is_agent"]
               "agent"
             else
               "customer"
             end

      next if User.exists?(email: email)

      user = User.new(
        email:              email,
        fullname:           profile["fullname"].presence || email.split("@").first.capitalize,
        contact_no:         profile["contact_no"].presence,
        address:            profile["address"].presence,
        role:               role,
        is_active:          f["is_active"],
        first_time:         profile["first_time"].nil? ? true : profile["first_time"],
        encrypted_password: BCrypt::Password.create(SecureRandom.hex(12)),
        created_at:         f["date_joined"],
        updated_at:         f["date_joined"],
      )
      user.save!(validate: false)
      imported_users += 1
      dot
    end
    puts "\n    #{imported_users} users imported."

    # Reload full email→id map (includes pre-existing users)
    user_email_map = User.pluck(:email, :id).to_h

    # ── 4. Tickets ───────────────────────────────────────────────────────
    puts "\n==> Migrating tickets"
    ticket_id_map   = {}
    ticket_type_map = {}   # django pk → new_type string
    imported_tickets = 0
    skipped_tickets  = 0

    tickets_raw.each do |rec|
      f        = rec["fields"]
      new_type = TICKET_TYPE_MAP[f["ticket_type"]]
      unless new_type
        puts "    WARN: unknown ticket_type '#{f['ticket_type']}' (pk #{rec['pk']}) — skipped"
        skipped_tickets += 1
        next
      end

      created_at = parse_datetime(f["created_date"], f["created_time"])

      ticket = Ticket.new(
        ticket_type:  new_type,
        title:        f["title"].presence || new_type.humanize,
        status:       STATUS_MAP[f["status"]] || "open",
        location_id:  location_id_map[f["location"]],
        customer_id:  user_email_map[f["customer"]&.downcase&.strip],
        assignee_id:  user_email_map[f["assignee"]&.downcase&.strip],
        is_emailsent: f["is_emailsent"],
        created_at:   created_at,
        updated_at:   created_at,
      )
      ticket.save!(validate: false)
      ticket_id_map[rec["pk"]]   = ticket.id
      ticket_type_map[rec["pk"]] = new_type
      imported_tickets += 1
      dot
    end
    puts "\n    #{imported_tickets} tickets imported, #{skipped_tickets} skipped."

    # ── 5. Ticket Details → TicketMessages + HiringDetail/TerminationDetail ─
    puts "\n==> Migrating ticket messages"
    imported_messages      = 0
    imported_hiring        = 0
    imported_term          = 0
    imported_metadata      = 0

    HTML_PATTERN = /<\s*(p|br|div|span|ul|ol|li|strong|em|a|img|table|tr|td|h[1-6])\b/i

    # Ticket columns that can be populated from parsed HTML fields (case-insensitive key match)
    TICKET_FIELD_MAP = {
      "title"       => "title",
      "subject"     => "title",
      "status"      => "status",
      "resolution"  => "resolution",
    }.freeze

    # Pre-compute the first message pk per ticket so we only process details once
    first_message_pk = details_raw
      .select { |r| ticket_id_map.key?(r["fields"]["ticket_no"]) }
      .group_by { |r| r["fields"]["ticket_no"] }
      .transform_values { |recs|
        recs.min_by { |r| [r["fields"]["created_date"], r["fields"]["created_time"]] }["pk"]
      }

    details_raw.each do |rec|
      f          = rec["fields"]
      django_pk  = f["ticket_no"]
      ticket_id  = ticket_id_map[django_pk]
      next unless ticket_id

      created_at  = parse_datetime(f["created_date"], f["created_time"])
      body        = f["details"].presence || "(no details)"
      is_html     = HTML_PATTERN.match?(body)
      ticket_type = ticket_type_map[django_pk]
      is_first    = first_message_pk[django_pk] == rec["pk"]

      parsed_fields = is_html ? parse_html_fields(body) : nil

      TicketMessage.create!(
        ticket_id:       ticket_id,
        sender_id:       user_email_map[f["sender"]&.downcase&.strip],
        details:         body,
        structured_data: parsed_fields.presence,
        message_type:    "customer_reply",
        message_id:      f["message_id"],
        mail_to:         f["mail_to"],
        mail_cc:         f["mail_cc"],
        mail_subject:    f["mail_subject"],
        is_html:         is_html,
        created_at:      created_at,
        updated_at:      created_at,
      )
      imported_messages += 1
      dot

      next unless is_first && parsed_fields.present?

      parsed = parsed_fields

      if ticket_type == "hiring_departure"
        # Determine hire vs termination from STATUS field or key presence
        status_val = parsed["STATUS"].to_s.strip.downcase
        ticket     = Ticket.find(ticket_id)

        if status_val == "hire" || (status_val.blank? && parsed["FULLNAME"].present?)
          create_hiring_detail(ticket, parsed)
          imported_hiring += 1
        elsif %w[termination terminate departure].include?(status_val) ||
              (status_val.blank? && (parsed["TERMINATION REASON"].present? || parsed["REASON"].present?))
          create_termination_detail(ticket, parsed)
          imported_term += 1
        end
      else
        # For all other ticket types: map known keys to ticket columns,
        # store the remainder in metadata.
        ticket_updates = {}
        metadata       = {}

        parsed.each do |raw_key, val|
          col = TICKET_FIELD_MAP[raw_key.downcase.strip]
          if col
            ticket_updates[col] = val.is_a?(Array) ? val.join(", ") : val.to_s.strip
          else
            metadata[raw_key] = val
          end
        end

        update_attrs = ticket_updates.merge(metadata: metadata)
        Ticket.where(id: ticket_id).update_all(update_attrs) if update_attrs.any?
        imported_metadata += 1
      end
    end
    puts "\n    #{imported_messages} messages imported."
    puts "    #{imported_hiring} hiring details created."
    puts "    #{imported_term} termination details created."
    puts "    #{imported_metadata} tickets enriched from HTML metadata."

    # ── 6. Ticket Notifications ──────────────────────────────────────────
    puts "\n==> Migrating ticket notifications"
    imported_notifs = 0
    skipped_notifs  = 0

    notifs_raw.each do |rec|
      f         = rec["fields"]
      ticket_id = ticket_id_map[f["ticket_id"].to_i]
      unless ticket_id
        skipped_notifs += 1
        next
      end

      created_at = parse_datetime(f["created_date"], f["created_time"])

      TicketNotification.create!(
        ticket_id:       ticket_id,
        responded_by_id: user_email_map[f["responded_by"]&.downcase&.strip],
        receiver_id:     user_email_map[f["receiver"]&.downcase&.strip],
        details:         f["details"],
        status:          f["status"].presence || "read",
        created_at:      created_at,
        updated_at:      created_at,
      )
      imported_notifs += 1
      dot
    end
    puts "\n    #{imported_notifs} notifications imported, #{skipped_notifs} skipped (orphaned ticket)."

    # ── 7. Ticket File Attachments ───────────────────────────────────────
    puts "\n==> Attaching ticket files/images from media/"
    attached_files  = 0
    missing_files   = 0
    skipped_files   = 0

    ticket_files_raw.each do |rec|
      f          = rec["fields"]
      django_pk  = f["ticket_no"].to_i
      image_path = f["images"].to_s.strip
      file_path  = f["file"].to_s.strip

      ticket = Ticket.find_by(id: ticket_id_map[django_pk])
      unless ticket
        skipped_files += 1
        next
      end

      candidates = []
      candidates << MEDIA_DIR.join(image_path) if image_path.present? && image_path != "False"
      candidates << MEDIA_DIR.join(file_path)  if file_path.present?  && file_path  != "False"

      candidates.each do |abs_path|
        unless abs_path.exist?
          puts "    [MISSING]  django_ticket=#{django_pk} → new_ticket=#{ticket.id} | #{abs_path}"
          missing_files += 1
          next
        end

        filename     = abs_path.basename.to_s
        io           = File.open(abs_path)
        content_type = Marcel::MimeType.for(io, name: filename)
        io.rewind

        ticket.attachments.attach(io: io, filename: filename, content_type: content_type)
        io.close
        attached_files += 1
        puts "    [ATTACHED] django_ticket=#{django_pk} → new_ticket=#{ticket.id} | #{abs_path.relative_path_from(Rails.root)}"
      end
    end
    puts "\n    #{attached_files} files attached, #{missing_files} missing, #{skipped_files} skipped (no ticket)."

    # ── Summary ──────────────────────────────────────────────────────────
    puts "\n#{'=' * 50}"
    puts "Migration complete!"
    puts "  Locations:     #{location_id_map.size}"
    puts "  Teams:         #{teams_raw.size}"
    puts "  Users:         #{imported_users} imported"
    puts "  Tickets:       #{imported_tickets} imported (#{skipped_tickets} skipped)"
    puts "  Messages:      #{imported_messages}"
    puts "  Hiring details:      #{imported_hiring}"
    puts "  Termination details: #{imported_term}"
    puts "  Tickets w/ metadata: #{imported_metadata}"
    puts "  Notifications: #{imported_notifs} imported (#{skipped_notifs} skipped)"
    puts "  Files attached:  #{attached_files} (#{missing_files} missing, #{skipped_files} skipped)"
    puts "#{'=' * 50}"
    puts "\nNOTE: Imported users have random passwords. Direct them to use 'Forgot Password'."
  end
end
