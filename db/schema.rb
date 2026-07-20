# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_07_20_150432) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "hiring_details", force: :cascade do |t|
    t.bigint "ticket_id", null: false
    t.date "start_date"
    t.date "date_of_birth"
    t.string "title_position"
    t.boolean "is_provider", default: false, null: false
    t.string "department"
    t.string "gender"
    t.string "cell_phone"
    t.string "badge_number"
    t.string "credentials_send_to"
    t.string "existing_pc_user"
    t.text "additional_info"
    t.string "pc_requirement"
    t.string "access_systems", default: [], array: true
    t.string "distribution_groups", default: [], array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "billing_provider_name"
    t.string "provider_npi"
    t.boolean "q5_q6_modifier_required", default: false, null: false
    t.string "q5_q6_modifier"
    t.string "microsoft_teams_department", default: [], array: true
    t.index ["ticket_id"], name: "index_hiring_details_on_ticket_id"
  end

  create_table "locations", force: :cascade do |t|
    t.string "name", null: false
    t.string "abbreviation", null: false
    t.string "state", null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_locations_on_name", unique: true
  end

  create_table "teams", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "manager_id"
    t.index ["name"], name: "index_teams_on_name", unique: true
  end

  create_table "termination_details", force: :cascade do |t|
    t.bigint "ticket_id", null: false
    t.string "termination_reason"
    t.date "termination_date"
    t.string "termination_time"
    t.string "email_address"
    t.string "key_card"
    t.boolean "email_forward_needed", default: false, null: false
    t.string "email_forwarded_to"
    t.boolean "historical_email_access", default: false, null: false
    t.text "additional_instructions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ticket_id"], name: "index_termination_details_on_ticket_id"
  end

  create_table "ticket_assignments", force: :cascade do |t|
    t.bigint "ticket_id", null: false
    t.bigint "assigned_to_id", null: false
    t.bigint "assigned_from_id"
    t.bigint "assigned_by_id", null: false
    t.text "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_by_id"], name: "index_ticket_assignments_on_assigned_by_id"
    t.index ["assigned_from_id"], name: "index_ticket_assignments_on_assigned_from_id"
    t.index ["assigned_to_id"], name: "index_ticket_assignments_on_assigned_to_id"
    t.index ["ticket_id"], name: "index_ticket_assignments_on_ticket_id"
  end

  create_table "ticket_messages", force: :cascade do |t|
    t.bigint "ticket_id", null: false
    t.bigint "sender_id"
    t.text "details", null: false
    t.string "message_type", default: "customer_reply", null: false
    t.string "message_id"
    t.string "mail_to"
    t.string "mail_cc"
    t.string "mail_subject"
    t.boolean "is_html", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "internal_note", default: false, null: false
    t.jsonb "structured_data"
    t.index ["message_type"], name: "index_ticket_messages_on_message_type"
    t.index ["sender_id"], name: "index_ticket_messages_on_sender_id"
    t.index ["ticket_id"], name: "index_ticket_messages_on_ticket_id"
  end

  create_table "ticket_notifications", force: :cascade do |t|
    t.bigint "ticket_id"
    t.bigint "responded_by_id"
    t.bigint "receiver_id"
    t.text "details"
    t.string "status", default: "unread", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["receiver_id"], name: "index_ticket_notifications_on_receiver_id"
    t.index ["responded_by_id"], name: "index_ticket_notifications_on_responded_by_id"
    t.index ["status"], name: "index_ticket_notifications_on_status"
    t.index ["ticket_id"], name: "index_ticket_notifications_on_ticket_id"
  end

  create_table "tickets", force: :cascade do |t|
    t.string "ticket_type", null: false
    t.string "title", null: false
    t.string "status", default: "open", null: false
    t.bigint "location_id"
    t.bigint "customer_id"
    t.bigint "assignee_id"
    t.bigint "assigned_by_id"
    t.bigint "resolved_by_id"
    t.boolean "is_emailsent", default: false, null: false
    t.datetime "assigned_at"
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "created_by_id"
    t.jsonb "metadata", default: {}, null: false
    t.text "resolution"
    t.index ["assigned_by_id"], name: "index_tickets_on_assigned_by_id"
    t.index ["assignee_id"], name: "index_tickets_on_assignee_id"
    t.index ["created_by_id"], name: "index_tickets_on_created_by_id"
    t.index ["customer_id"], name: "index_tickets_on_customer_id"
    t.index ["location_id"], name: "index_tickets_on_location_id"
    t.index ["resolved_by_id"], name: "index_tickets_on_resolved_by_id"
    t.index ["status"], name: "index_tickets_on_status"
    t.index ["ticket_type"], name: "index_tickets_on_ticket_type"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "fullname", default: "", null: false
    t.string "contact_no", limit: 13
    t.string "address", limit: 200
    t.string "role", default: "customer", null: false
    t.boolean "is_active", default: true, null: false
    t.boolean "first_time", default: true, null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "team_id"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["team_id"], name: "index_users_on_team_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "hiring_details", "tickets"
  add_foreign_key "termination_details", "tickets"
  add_foreign_key "ticket_assignments", "tickets"
  add_foreign_key "ticket_assignments", "users", column: "assigned_by_id"
  add_foreign_key "ticket_assignments", "users", column: "assigned_from_id"
  add_foreign_key "ticket_assignments", "users", column: "assigned_to_id"
  add_foreign_key "ticket_messages", "tickets"
  add_foreign_key "ticket_messages", "users", column: "sender_id"
  add_foreign_key "ticket_notifications", "tickets"
  add_foreign_key "ticket_notifications", "users", column: "receiver_id"
  add_foreign_key "ticket_notifications", "users", column: "responded_by_id"
  add_foreign_key "tickets", "locations"
  add_foreign_key "tickets", "users", column: "assigned_by_id"
  add_foreign_key "tickets", "users", column: "assignee_id"
  add_foreign_key "tickets", "users", column: "created_by_id"
  add_foreign_key "tickets", "users", column: "customer_id"
  add_foreign_key "tickets", "users", column: "resolved_by_id"
  add_foreign_key "users", "teams"
end
