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
      "Hiring"         => "hiring",
      "Termination"    => "departure",
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
 
    # Legacy exports used two label vocabularies over time (an old terse
    # all-caps set and a newer verbose one) — each field is looked up
    # under every known variant, first match wins.
    def dig_field(fields, *keys)
      keys.each { |k| v = fields[k]; return v if v.present? }
      nil
    end

    def create_hiring_detail(ticket, fields)
      start_date = begin
        Date.parse(dig_field(fields, "START DATE").to_s)
      rescue StandardError
        nil
      end

      date_of_birth = begin
        Date.parse(dig_field(fields, "Date of Birth", "DATE OF BIRTH").to_s)
      rescue StandardError
        nil
      end

      access_raw = Array(dig_field(fields, "ACCESS SYSTEMS", "What Access/Systems Are Needed"))
      dist_raw   = Array(dig_field(fields, "DISTRIBUTION", "What Distribution Groups should the new team mate be added to if any"))

      HiringDetail.create!(
        ticket_id:                  ticket.id,
        start_date:                 start_date,
        date_of_birth:              date_of_birth,
        title_position:             dig_field(fields, "POSITION", "Title/Position").presence,
        department:                 dig_field(fields, "DEPARTMENT", "Please select their Department").presence,
        gender:                     dig_field(fields, "GENDER", "Gender").presence,
        cell_phone:                 dig_field(fields, "CONTACT", "Cell Phone Number").presence,
        badge_number:               dig_field(fields, "BADGE NO", "What is the badge/key card number", "What is the badge/keycard Number").presence,
        credentials_send_to:        dig_field(fields, "CREDENTIALS", "Who shoud we send their credentials to if anyone", "Who should we send their credentials to if anyone").presence,
        existing_pc_user:           dig_field(fields, "EXISTING PC USER", "If existing PC , Who was using before").presence,
        pc_requirement:             dig_field(fields, "PC REUIREMENTS", "PC REQUIREMENTS", "PC Requirements").presence,
        additional_info:            dig_field(fields, "USEFUL INFO", "Any other information that would be useful to know").presence,
        microsoft_teams_department: Array(dig_field(fields, "MICROSOFT TEAMS", "What Microsoft Teams should the member be a part of")).join(", ").presence,
        access_systems:             access_raw.reject { |v| v.casecmp?("none") },
        distribution_groups:        dist_raw.reject { |v| v.casecmp?("none") },
      )
    end

    def create_termination_detail(ticket, fields)
      term_date = begin
        Date.parse(dig_field(fields, "TERMINATION DATE").to_s)
      rescue StandardError
        nil
      end

      TerminationDetail.create!(
        ticket_id:               ticket.id,
        termination_reason:      dig_field(fields, "TERMINATION REASON", "REASON").presence,
        termination_date:        term_date,
        termination_time:        dig_field(fields, "TERMINATION TIME").presence,
        email_address:           dig_field(fields, "EMAIL", "EMAIL ADDRESS").presence,
        key_card:                dig_field(fields, "KEY CARD", "Keycard").presence,
        email_forwarded_to:      dig_field(fields, "FORWARDED TO", "EMAIL FORWARDED TO").presence,
        additional_instructions: dig_field(fields, "USEFUL INFO", "ADDITIONAL INFO", "MISSED INFO").presence,
      )
    end
 
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
    users_raw     = load_json("users.json")
    my_users_raw  = load_json("my_users.json")
    teams_raw     = load_json("teams.json")
    locations_raw = load_json("locations.json")
    tickets_raw   = load_json("tickets.json")
    details_raw   = load_json("ticket_details.json")
    notifs_raw    = load_json("ticket_notifications.json")
 
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
    imported_messages  = 0
    imported_hiring    = 0
    imported_term      = 0
    imported_metadata  = 0

    HTML_PATTERN = /<\s*(p|br|div|span|ul|ol|li|strong|em|a|img|table|tr|td|h[1-6])\b/i

    # Legacy HTML label (downcased) → metadata key actually read by the app
    # (see Ticket::CATALOGUE forms / tickets_controller#ticket_params).
    METADATA_KEY_MAP = {
      "description" => "details",
      "reason"      => "details",
      "information" => "details",
      "issue"       => "issue",
      "ideas"       => "idea_types",
      "great work"  => "work_types",
      "mobile"      => "mobile",
      "contact"     => "mobile",
    }.freeze
    ARRAY_METADATA_KEYS = %w[idea_types work_types hr_types].freeze

    details_raw.each do |rec|
      f          = rec["fields"]
      django_pk  = f["ticket_no"]
      ticket_id  = ticket_id_map[django_pk]
      next unless ticket_id

      created_at  = parse_datetime(f["created_date"], f["created_time"])
      body        = f["details"].presence || "(no details)"
      is_html     = HTML_PATTERN.match?(body)
      ticket_type = ticket_type_map[django_pk]
      parsed      = is_html ? parse_html_fields(body) : {}

      TicketMessage.create!(
        ticket_id:       ticket_id,
        sender_id:       user_email_map[f["sender"]&.downcase&.strip],
        details:         body,
        structured_data: parsed.presence,
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

      next if parsed.blank?

      # Parse structured fields from the HTML body and create detail records
      if ticket_type.in?(%w[hiring departure])
        status = parsed["STATUS"].to_s.strip.downcase

        ticket = Ticket.find(ticket_id)

        if status == "hire"
          create_hiring_detail(ticket, parsed)
          imported_hiring += 1
        elsif %w[termination terminate departure].include?(status) ||
              (status.blank? && (parsed["TERMINATION REASON"].present? || parsed["REASON"].present?))
          create_termination_detail(ticket, parsed)
          imported_term += 1
        end
      else
        # For all other ticket types: map known legacy labels onto the
        # metadata keys the app reads; anything unrecognized is kept as
        # extra metadata rather than dropped.
        metadata = {}

        parsed.each do |raw_key, val|
          key = METADATA_KEY_MAP[raw_key.downcase.strip]
          next if key.nil? && raw_key.blank?
          key ||= raw_key.downcase.strip.gsub(/\s+/, "_")

          if ARRAY_METADATA_KEYS.include?(key)
            metadata[key] = Array(metadata[key]) + Array(val)
          else
            metadata[key] = val.is_a?(Array) ? val.join(", ") : val.to_s.strip
          end
        end

        if metadata.present?
          existing = Ticket.where(id: ticket_id).pick(:metadata) || {}
          Ticket.where(id: ticket_id).update_all(metadata: existing.merge(metadata))
          imported_metadata += 1
        end
      end
    end
    puts "\n    #{imported_messages} messages imported."
    puts "    #{imported_metadata} tickets updated with parsed metadata."
    puts "    #{imported_hiring} hiring details created."
    puts "    #{imported_term} termination details created."
 
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
    puts "\n==> Migrating ticket attachments"
    files_raw         = load_json("ticket_files.json")
    MEDIA_ROOT        = Rails.root.join("ticket_media")
    attached_count    = 0
    missing_count     = 0
    orphan_count      = 0
 
    files_raw.each do |rec|
      f         = rec["fields"]
      ticket_id = ticket_id_map[f["ticket_no"]]
      unless ticket_id
        orphan_count += 1
        next
      end
 
      ticket = Ticket.find(ticket_id)
 
      [[f["images"], :image], [f["file"], :file]].each do |raw_path, kind|
        next if raw_path.blank? || raw_path == "False"
 
        # Images were stored under technicalImages/user_N/filename
        # Files were stored flat — both live in ticket_media/ now
        rel_path  = raw_path.sub(/\Atechnical[Ii]mages\//, "")
        full_path = MEDIA_ROOT.join(rel_path)
 
        unless File.exist?(full_path)
          missing_count += 1
          next
        end
 
        filename = File.basename(full_path)
        ticket.attachments.attach(
          io:       File.open(full_path),
          filename: filename
        )
        attached_count += 1
        dot
      end
    end
    puts "\n    #{attached_count} files attached, #{missing_count} missing, #{orphan_count} orphaned."
 
    # ── Summary ──────────────────────────────────────────────────────────
    puts "\n#{'=' * 50}"
    puts "Migration complete!"
    puts "  Locations:           #{location_id_map.size}"
    puts "  Teams:               #{teams_raw.size}"
    puts "  Users:               #{imported_users} imported"
    puts "  Tickets:             #{imported_tickets} imported (#{skipped_tickets} skipped)"
    puts "  Messages:            #{imported_messages}"
    puts "  Hiring details:      #{imported_hiring}"
    puts "  Termination details: #{imported_term}"
    puts "  Notifications:       #{imported_notifs} imported (#{skipped_notifs} skipped)"
    puts "  Attachments:         #{attached_count} attached (#{missing_count} missing)"
    puts "#{'=' * 50}"
    puts "\nNOTE: Imported users have random passwords. Direct them to use 'Forgot Password'."
  end
end
 
 